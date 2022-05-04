;
; crt0.s for NES, using NROM (no mapper)
;
; Provides:
;  * Start-up code clearing RAM and VRAM
;  * Constant-cycle-time NMI handler, performing sprite DMA and VRAM writes via transfer buffer at $100
;  * _putchar routine, to support printf
;  * 16-bit frame counter _sys_time, to support VM routines
.module crt0
.globl _sys_time
.globl __current_bank
.globl _putchar
.globl _wait_vbl_done, .wait_vbl_done
.globl _shadow_OAM

__CRT0_SPRITE_PAGE = 0x200
_shadow_OAM = 0x200

; Declare a dummy symbol for banking
; TODO: Make banking actually work
b_wait_frames = 0
.globl b_wait_frames

.macro WRITE_PALETTE_SHADOW
    lda #>0x3F00
    sta 0x2006
    lda #<0x3F00
    sta 0x2006
    ldx *__crt0_paletteShadow
    i = 0
.rept 8
    stx 0x2007
    lda *(__crt0_paletteShadow+1+3*i+0)
    sta 0x2007
    lda *(__crt0_paletteShadow+1+3*i+1)
    sta 0x2007
    lda *(__crt0_paletteShadow+1+3*i+2)
    sta 0x2007
    i = i + 1
.endm
.endm

.area ZP (PAG)
__shadow_OAM_base::                     .ds 1
__current_bank:                         .ds 1
_sys_time:                              .ds 2
_shadow_PPUCTRL:                        .ds 1
_shadow_PPUMASK:                        .ds 1
__crt0_paletteShadow:                   .ds 25
__crt0_spritePageValid:                 .ds 1
__crt0_NMI_Done:                        .ds 1
__crt0_NMI_insideNMI:                   .ds 1
__crt0_ScrollHV:                        .ds 1
__crt0_drawListValid:                   .ds 1
__crt0_drawListNumDelayCycles_x8:       .ds 1
__crt0_drawListPosR:                    .ds 1
__crt0_drawListPosW:                    .ds 1
__crt0_textPPUAddr:                     .ds 2
__crt0_NMITEMP:                         .ds 4
__crt0_textTemp:                        .ds 1

;
; Causes two errors:
; 
; ?ASlink-Warning-Paged Area BSS Length Error
; ?ASlink-Warning-Paged Area BSS Boundary Error
; 
;.area BSS (PAG)
;_shadow_OAM::                           .ds 256

.area CRT0CODE
__crt0_NMI:
    ; Prevent NMI re-entry
    bit __crt0_NMI_insideNMI
    bpl NotInsideNMI
    rti
NotInsideNMI:
    pha
    txa
    pha
    tya
    pha

    lda #0x80
    sta *__crt0_NMI_insideNMI

    jsr __crt0_doSpriteDMA
    jsr __crt0_NMI_doUpdateVRAM

    nop
    ; Enable screen to get normal dot crawl pattern
    lda *_shadow_PPUMASK
    sta 0x2001

    lda *_sys_time
    clc
    adc #1
    sta *_sys_time
    lda *(_sys_time+1)
    adc #0
    sta *(_sys_time+1)

    lda #0x80
    sta __crt0_NMI_Done
    
    lda *_shadow_PPUCTRL
    ora *__crt0_ScrollHV
    sta 0x2000

    pla
    tay
    pla
    tax
    pla
    asl *__crt0_NMI_insideNMI
    rti

__crt0_NMI_doUpdateVRAM:
    lda *_shadow_PPUMASK
    and #0x18
    beq __crt0_NMI_doUpdateVRAM_blanked
    ; Not manually blanked - do updates
    lda 0x2002
    lda #0x08
    sta 0x2000
    lda #0
    sta 0x2001
    jsr DoUpdateVRAM
    ; Set scroll address
    lda #0x00
    sta 0x2006
    sta 0x2006
    rts
__crt0_NMI_doUpdateVRAM_blanked:
    ; Early-out if blanked to allow main code to do VRAM address / scroll updates
    rts

.bndry 0x100
__crt0_doSpriteDMA:
    bit __crt0_spritePageValid
    bpl __crt0_doSpriteDMA_spritePageInvalid
    lda #0                      ; +2
    sta 0x2003                  ; +4
    lda #>__CRT0_SPRITE_PAGE    ; +2
    sta 0x4014                  ; +512/513
    rts
__crt0_doSpriteDMA_spritePageInvalid:
    ; Delay 520 cycles to keep timing consistent
    ldx #104
__crt0_doSpriteDMA_loop:
    dex
    bne __crt0_doSpriteDMA_loop
    rts

DoUpdateVRAM:
    WRITE_PALETTE_SHADOW
    bit __crt0_drawListValid
    bpl DoUpdateVRAM_drawListInvalid
    jsr ProcessDrawList
    ; Delay up to 167*8-1 = 1575 cycles (value set by draw list creation code)
    ; ...plus fixed-cost of 56 cycles
    ldx __crt0_drawListNumDelayCycles_x8
DoUpdateVRAM_valid_loop:
    stx __crt0_drawListNumDelayCycles_x8
    dex
    bne DoUpdateVRAM_valid_loop
    lda #169
    sta __crt0_drawListNumDelayCycles_x8
    rts
DoUpdateVRAM_drawListInvalid:
    ; Delay exactly 1633 cyles to keep timing consistent
    ldx #176
DoUpdateVRAM_invalid_loop:
    stx __crt0_drawListNumDelayCycles_x8
    dex
    bne DoUpdateVRAM_invalid_loop
    nop
    nop
    lda #169
    sta __crt0_drawListNumDelayCycles_x8
    rts

;
; Format of draw list
;
; 0: Data length
; 1: 4 if inc-by-32, 0 if inc-by-1
; 2: PPUADDR_HI
; 3: PPUADDR_LO
; 4: ...N data bytes...
;
; Number of cycles spent = 19 + 21 + 48*NumTransfers + 8*NumBytesTransferred
;                        = 56 + 48*NumTransfers + 8*NumBytesTransferred
;                        = 8 * (7 + 6*NumTransfers + NumBytesTransferred)
;                        = 8 * (6*NumTransfers + NumBytesTransferred + 7)
;
ProcessDrawList:
    ProcessDrawList_tempX  = __crt0_NMITEMP+2
    ProcessDrawList_addr   = __crt0_NMITEMP+0
    lda #>ProcessDrawList_UnrolledCopyLoop  ; +2
    sta ProcessDrawList_addr+1              ; +3
    tsx                                     ; +2
    stx ProcessDrawList_tempX               ; +3
    ldx #0 ;drawListPosR                    ; +2
    dex                                     ; +2
    txs                                     ; +2
    jmp ProcessDrawList_DoOneTransfer       ; +3
    ; Total = 2 + 3 + 2 + 3 + 2 + 2 + 2 + 3 = 19 fixed-cost entry

.bndry 0x100
ProcessDrawList_UnrolledCopyLoop:
.rept 64
pla             ; +4
sta 0x2007      ; +4
.endm
ProcessDrawList_DoOneTransfer:
    pla                                         ; +4
    beq ProcessDrawList_EndOfList               ; +2/3
    tay                                         ; +2
    ; branchaddr = 256-4*num_bytes = NOT(4*num_bytes)+1+256 = NOT(4*num_bytes)+1
    lda ProcessDrawList_NumBytesToAddress,y     ; +4
    sta *ProcessDrawList_addr                   ; +3
    pla                                         ; +4
    sta 0x2000                                  ; +4
    pla                                         ; +4
    sta 0x2006                                  ; +4
    pla                                         ; +4
    sta 0x2006                                  ; +4
    nop                                         ; +2
    nop                                         ; +2
    jmp [ProcessDrawList_addr]                  ; +5
    ; Total = 4 + 2 + 2 + 4 + 3 + 6*4 + 2 + 2 + 5 = 48 for each transfer (...+ 8*NumBytesCopied)
    ;         4 + 3 + 14 = 7 + 14 = 21 fixed-cost exit

ProcessDrawList_EndOfList:
    tsx                                 ; +2
    inx                                 ; +2
    stx *__crt0_drawListPosR            ; +3
    ldx *ProcessDrawList_tempX          ; +3
    txs                                 ; +2
    lda #0                              ; +2
    sta *__crt0_drawListPosW            ; +3
    sta *__crt0_drawListValid           ; +3
    rts                                 ; +6
    ; = 2 + 2 + 3 + 3 + 2 + 2 + 3 + 3 + 6 = 26

.bndry 0x100
ProcessDrawList_NumBytesToAddress:
i = 0
.rept 65
.db <(256-4*i)
i = i + 1
.endm

_putchar:
    cmp #10
    bne _putcharNotEndOfLine
    ; Newline character sent.
    ; Just increase current PPU write address to next line (and start at column 1)
    lda *__crt0_textPPUAddr
    and #0xE0
    clc
    adc #0x20
    ora #1
    sta *__crt0_textPPUAddr
    lda *(__crt0_textPPUAddr+1)
    adc #0
    sta *(__crt0_textPPUAddr+1)
    rts
_putcharNotEndOfLine:
    pha
    sty *__crt0_textTemp
; Prevent main code from writing too much data by waiting for NMI to flush transfer buffer if >= 32 bytes
_putcharWaitForFlush:
    ldy *__crt0_drawListPosW
    tya
    and #0xC8
    bne _putcharWaitForFlush
    ; Just write each character as a separate single-byte write
    ; TODO: Optimize to handle continuous characters as multi-byte transfer for less blocking
    clc
    ror *__crt0_drawListValid
    ldy *__crt0_drawListPosW
    ; Number of bytes
    lda #1
    sta 0x100,y
    iny
    ; Horizontal mode
    lda #0
    sta 0x100,y
    iny
    ; PPU hi
    lda *(__crt0_textPPUAddr+1)
    sta 0x100,y
    iny
    ; PPU lo
    lda *__crt0_textPPUAddr
    sta 0x100,y
    iny
    pla
    sta 0x100,y
    iny
    ; zero byte at end
    lda #0
    sta 0x100,y
    ; decrease total delay in NMI by 7 * 8 cycles for each individually written byte
    ;
    ; Each new write operation adds 48 cycles + 8 cycles per written byte, i.e.:
    ;  NumDelayCycles_x8 -= 6 * numberOfWriteCommands + numWrittenBytes
    ;
    dec *__crt0_drawListNumDelayCycles_x8
    dec *__crt0_drawListNumDelayCycles_x8
    dec *__crt0_drawListNumDelayCycles_x8
    dec *__crt0_drawListNumDelayCycles_x8
    dec *__crt0_drawListNumDelayCycles_x8
    dec *__crt0_drawListNumDelayCycles_x8
    dec *__crt0_drawListNumDelayCycles_x8
    ; Increment PPU addr
    lda *__crt0_textPPUAddr
    clc
    adc #1
    sta *__crt0_textPPUAddr
    lda *(__crt0_textPPUAddr+1)
    adc #0
    sta *(__crt0_textPPUAddr+1)
    sty *__crt0_drawListPosW
    sec
    ror *__crt0_drawListValid
    ldy *__crt0_textTemp
    rts

__crt0_IRQ:
    jmp __crt0_IRQ

__crt0_setPalette:
    ; Set background color to 1D (black)
    lda #0x1D
    sta *__crt0_paletteShadow
    ; set all background sub-palettes to 00, 10, 20
    lda #0x00
    ldx #0x10
    ldy #0x20
    ;
    sta *(__crt0_paletteShadow+1)
    stx *(__crt0_paletteShadow+2)
    stx *(__crt0_paletteShadow+3)
    ;
    sta *(__crt0_paletteShadow+4)
    stx *(__crt0_paletteShadow+5)
    sty *(__crt0_paletteShadow+6)
    ;
    sta *(__crt0_paletteShadow+7)
    stx *(__crt0_paletteShadow+8)
    sty *(__crt0_paletteShadow+9)
    ;
    sta *(__crt0_paletteShadow+10)
    stx *(__crt0_paletteShadow+11)
    sty *(__crt0_paletteShadow+12)
    ; Set sprite palette to all unused (black)
    lda #0x1D
    sta *(__crt0_paletteShadow+13)
    sta *(__crt0_paletteShadow+14)
    sta *(__crt0_paletteShadow+15)
    sta *(__crt0_paletteShadow+16)
    sta *(__crt0_paletteShadow+17)
    sta *(__crt0_paletteShadow+18)
    sta *(__crt0_paletteShadow+19)
    sta *(__crt0_paletteShadow+20)
    sta *(__crt0_paletteShadow+21)
    sta *(__crt0_paletteShadow+22)
    sta *(__crt0_paletteShadow+23)
    sta *(__crt0_paletteShadow+24)
    rts

__crt0_waitPPU:
__crt0_waitPPU_loop:
    lda 0x2002
    bpl __crt0_waitPPU_loop
    rts

__crt0_clearRAM:
    ldx #0x00
    txa
__crt0_clearRAM_loop:
    sta 0x0000,x
    ;sta 0x0100,x
    sta 0x0200,x
    sta 0x0300,x
    sta 0x0400,x
    sta 0x0500,x
    sta 0x0600,x
    sta 0x0700,x
    inx
    bne __crt0_clearRAM_loop
    rts

__crt0_clearVRAM:
    lda #0x00
    sta 0x2006
    sta 0x2006
    ldy #64
    ldx #0
__crt0_clearVRAM_loop:
    sta 0x2007
    dex
    bne __crt0_clearVRAM_loop
    dey
    bne __crt0_clearVRAM_loop
    rts

.wait_vbl_done::
_wait_vbl_done::
    lda _sys_time
_wait_vbl_done_waitForNextFrame_loop:
    cmp _sys_time
    beq _wait_vbl_done_waitForNextFrame_loop
    rts

__crt0_RESET:
    ; Disable IRQs
    sei
    ; Set stack pointer
    ldx #0xff
    txs
    ; Set switchable bank to first
__crt0_RESET_bankSwitchValue:
    lda #0x00
    sta __crt0_RESET_bankSwitchValue+1 ;sta 0xC000
    ; Disable NMIs and rendering
    sta 0x2000
    sta 0x2001
    ; Wait for PPU warm-up
    jsr __crt0_waitPPU
    jsr __crt0_waitPPU
    ; Clear RAM and VRAM
    jsr __crt0_clearRAM
    jsr __crt0_clearVRAM
    ; Perform initialization of DATA area
    lda #<s_XINIT
    sta ___memcpy_PARM_2
    lda #>s_XINIT
    sta ___memcpy_PARM_2+1
    lda #<l_XINIT
    sta ___memcpy_PARM_3
    lda #>l_XINIT
    sta ___memcpy_PARM_3+1
    lda #<s_DATA
    ldx #>s_DATA
    jsr ___memcpy
    ; Set palette shadow
    jsr __crt0_setPalette
    ; Initialize PPU address for printf output (start at 3rd row, 2nd column)
    lda #<0x2041
    sta __crt0_textPPUAddr
    lda #>0x2041
    sta *(__crt0_textPPUAddr+1)
    lda #0
    sta *__crt0_drawListPosW
    sta *__crt0_drawListPosR
    ; 
    lda #0x18
    sta *_shadow_PPUMASK
    ; enable NMI
    lda #0x80
    sta *_shadow_PPUCTRL
    sta 0x2000
    ; Call main
    jsr _main
    ; main finished - loop forever
__crt0_waitForever:
    jmp __crt0_waitForever

.display_off::
_display_off::
    lda *_shadow_PPUMASK
    and #0xE7
    sta *_shadow_PPUMASK
    sta 0x2001
    rts

.display_on::
_display_on::
    lda *_shadow_PPUMASK
    ora #0x18
    sta *_shadow_PPUMASK
    sta 0x2001
    rts

; Interrupt / RESET vector table
.area VECTORS (ABS)
.org 0xfffa
.dw	__crt0_NMI
.dw	__crt0_RESET
.dw	__crt0_IRQ
