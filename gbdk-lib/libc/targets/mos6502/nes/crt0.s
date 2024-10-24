;
; crt0.s for NES targeting bb-studio, using GBDK8x8 mapper
;
; Provides:
;  * Start-up code clearing RAM and VRAM
;  * Constant-cycle-time NMI handler, performing sprite DMA and VRAM writes via transfer buffer at $100
;  * 16-bit frame counter _sys_time, to support VM routines
.module crt0
.include    "global.s"

; OAM CPU page
_shadow_OAM             = 0x200
; Attribute shadow (64 bytes, leaving 56 bytes available for CPU stack)
_attribute_shadow       = 0x7F00 ;0x188

.macro WRITE_PALETTE_SHADOW
    lda #>0x3F00
    sta PPUADDR
    lda #<0x3F00
    sta PPUADDR
    ldx __crt0_paletteShadow
    i = 0
.rept 7
    stx PPUDATA
    lda (__crt0_paletteShadow+1+3*i+0)
    sta PPUDATA
    lda (__crt0_paletteShadow+1+3*i+1)
    sta PPUDATA
    lda (__crt0_paletteShadow+1+3*i+2)
    sta PPUDATA
    i = i + 1
.endm
    ; Last sub-palette backdrop should contain textbox-backdrop 
    i = 7
    ldx *__textbox_backdrop
    stx PPUDATA
    lda (__crt0_paletteShadow+1+3*i+0)
    sta PPUDATA
    lda (__crt0_paletteShadow+1+3*i+1)
    sta PPUDATA
    lda (__crt0_paletteShadow+1+3*i+2)
    sta PPUDATA
.endm

       ;; ****************************************

        ;; Ordering of segments for the linker
        ;; Code that really needs to be in the fixed bank
        .area _CODE
        .area _HOME
        ;; Similar to _HOME
        .area _BASE
        ;; Constant data
        .area _LIT
        .area _RODATA
        ;; Constant data, used to init _DATA
        .area _INITIALIZER
        .area _XINIT
        ;; Code, used to init _DATA
        .area _GSINIT 
        .area _GSFINAL
        ;; Uninitialised ram data
        .area _DATA
        .area _BSS
        ;; Initialised in ram data
        .area _INITIALIZED
        ;; For malloc
        .area _HEAP
        .area _HEAP_END

.area	OSEG (PAG, OVR)
.area	GBDKOVR (PAG, OVR)
__add_palette_rewrite_PARM_3::          .ds 1
__add_palette_rewrite_PARM_4::          .ds 1

.area _ZP (PAG)
__current_bank::                        .ds 1
_sys_time::                             .ds 2
_sys_time_old::                         .ds 1
_shadow_PPUCTRL::                       .ds 1
_shadow_PPUMASK::                       .ds 1
__crt0_spritePageValid::                .ds 1
__crt0_disableNMI:                      .ds 1
_bkg_scroll_x::                         .ds 1
_bkg_scroll_y::                         .ds 1
_attribute_row_dirty::                  .ds 1
_attribute_column_dirty::               .ds 1
_attribute_shadow_offset::              .ds 1
.crt0_forced_blanking::                 .ds 1
__SYSTEM::                              .ds 1
.ldx_mapper_config:                     .ds 1
__vbl_isr_mapper_config:                .ds 1
__ESI_scanline_counter:                 .ds 1
__ESI_write_index:                      .ds 1
__CFG_REG_cache:                        .ds 1
__textbox_backdrop:                     .ds 1
__inside_nop_slide:                     .ds 1

.define __crt0_NMITEMP "___SDCC_m6502_ret4"

.area _BSS
__crt0_paletteShadow::                  .ds 25
__shadow_OAM_base::                     .ds 1
.mode::                                 .ds 1
__lcd_isr_PPUCTRL:                      .ds (2*.MAX_DEFERRED_ISR_CALLS)
__lcd_isr_PPUMASK:                      .ds (2*.MAX_DEFERRED_ISR_CALLS)
__lcd_isr_pal_c0:
__lcd_isr_scroll_x:                     .ds (2*.MAX_DEFERRED_ISR_CALLS)
__lcd_isr_pal_c1:
__lcd_isr_scroll_y:                     .ds (2*.MAX_DEFERRED_ISR_CALLS)
__lcd_isr_delay_num_scanlines:          .ds (2*.MAX_DEFERRED_ISR_CALLS)
__lcd_isr_pal_c2:
__lcd_isr_mapper_config:                .ds (2*.MAX_DEFERRED_ISR_CALLS)
__lcd_isr_ppuaddr_lo:                   .ds (2*.MAX_DEFERRED_ISR_CALLS)
__lcd_isr_pal_c3:                       .ds (2*.MAX_DEFERRED_ISR_CALLS)
__lcd_isr_num_calls:                    .ds 2
__lcd_isr_buf_length:                   .ds 1
_attribute_row_dirty_planes::           .ds 4
_attribute_column_dirty_planes::        .ds 4
__lcd_isr_read_buf:                     .ds 1


.area _CODE

.bndry 0x100
.identity::
_identity::
i = 0
.rept 256
.db i
i = i + 1
.endm

.define ProcessDrawList_tempX "__crt0_NMITEMP+2"
.define ProcessDrawList_addr  "__crt0_NMITEMP+0"

.bndry 0x100
    nop         ; Pad to offset, to support zero-terminator value
ProcessDrawList_UnrolledCopyLoop:
.rept 32
pla             ; +4
sta PPUDATA     ; +4
.endm
ProcessDrawList_DoOneTransfer:
    pla                                         ; +4
    beq ProcessDrawList_EndOfList               ; +2/3
    sta *ProcessDrawList_addr                   ; +3
    pla                                         ; +4
    sta PPUCTRL                                 ; +4
    pla                                         ; +4
    sta PPUADDR                                 ; +4
    
    ;tay
    ;sta [*.identity_ptr],y
    
    pla                                         ; +4
    sta PPUADDR                                 ; +4

    pla
    sta CFG_REG ;0xC000

    nop                                         ; +2
    jmp [ProcessDrawList_addr]                  ; +5
    ; Total = 4 + 2 + 2 + 4 + 3 + 6*4 + 2 + 2 + 5 = 48 for each transfer (...+ 8*NumBytesCopied)
    ;         4 + 3 + 14 = 7 + 14 = 21 fixed-cost exit

; .bndry 0x100 (skip alignment as previous alignment means page-cross won't happen)
__crt0_doSpriteDMA:
    bit *__crt0_spritePageValid
    bpl __crt0_doSpriteDMA_spritePageInvalid
    lda #0                      ; +2
    sta OAMADDR                 ; +4
    lda #>_shadow_OAM           ; +2
    sta OAMDMA                  ; +512/513
    rts
__crt0_doSpriteDMA_spritePageInvalid:
    ; Delay 520 cycles to keep timing consistent
    ldx #104
__crt0_doSpriteDMA_loop:
    dex
    bne __crt0_doSpriteDMA_loop
    rts

ProcessDrawList_EndOfList:
    ldx *ProcessDrawList_tempX          ; +3
    txs                                 ; +2
    lda #0                              ; +2
    sta *__vram_transfer_buffer_pos_w   ; +3
    sta *__vram_transfer_buffer_valid   ; +3
    rts                                 ; +6
    ; = 3 + 2 + 2 + 3 + 3 + 6 = 19

;
; Number of cycles spent = 19 + 21 + 48*NumTransfers + 8*NumBytesTransferred
;                        = 56 + 48*NumTransfers + 8*NumBytesTransferred
;                        = 8 * (7 + 6*NumTransfers + NumBytesTransferred)
;                        = 8 * (6*NumTransfers + NumBytesTransferred + 7)
;
ProcessDrawList:
    lda #>ProcessDrawList_UnrolledCopyLoop  ; +2
    sta *ProcessDrawList_addr+1             ; +3
    tsx                                     ; +2
    stx *ProcessDrawList_tempX              ; +3
    ldx #0xFF                               ; +2
    txs                                     ; +2
    jmp ProcessDrawList_DoOneTransfer       ; +3
    ; Total = 2 + 3 + 2 + 3 + 2 + 2 + 3 = 17 fixed-cost entry

.ifeq GBDK_NES_EVERY_SCANLINE_IRQ 
;
; Delays until specified (non-zero) scanline is reached
;
; First scanline's delay needs adjusting in coordination with .do_lcd_ppu_reg_writes
;
.define .acc "___SDCC_m6502_ret4"
.delay_to_lcd_scanline::
    jsr .delay_12_cycles
    jmp 2$
1$:
    jsr .delay_28_cycles
    jsr .delay_28_cycles
    jsr .delay_12_cycles ; -> 28 + 28 + 12 = 68 cycles
2$:

    jsr .delay_fractional   ; -> 40.666 NTSC cycles  33.5625 PAL cycles
  
    dex
    bne 1$      ; -> 5 cycles
    rts

.delay_28_cycles:
    jsr .delay_12_cycles
    nop
    nop
.delay_12_cycles:
    rts

;
; Takes 40.666 NTSC cycles / 33.5626 PAL cycles
;
.delay_fractional:
    lda #144 ; Initialize A with PAL fractional cycle count
    ; +7 cycles for NTSC scanlines
    bit *__SYSTEM
    bvs 3$
    lda #171 ; NTSC fractional cycle count
    nop
    nop
    nop
3$:             ; -> 15 NTSC cycles / 8 PAL cycles
    ; Add fractional cycles and branch on carry
    clc
    adc *.acc
    sta *.acc
    bcs 4$
4$:
    sta *.acc   ; -> 13.666 NTSC cycles / 13.5625 PAL cycles
    rts         ; -> 6 cycles for RTS, 6 cycles for JSR = 12 cycles

.endif

__crt0_NMI_earlyout:
    rti
__crt0_NMI:
    bit *__crt0_disableNMI
    bmi __crt0_NMI_earlyout
    pha
    txa
    pha
    tya
    pha
    
    ; Skip graphics updates if blanked, to allow main code to do VRAM address / scroll updates
    lda *_shadow_PPUMASK
    and #(PPUMASK_SHOW_BG | PPUMASK_SHOW_SPR)
    beq __crt0_NMI_skip
    ; Do Sprite DMA or delay equivalent cycles
    jsr __crt0_doSpriteDMA
    ; Update VRAM
    lda PPUSTATUS
    lda #PPUCTRL_SPR_CHR
    sta PPUCTRL
    jsr DoUpdateVRAM  

.ifne GBDK_NES_EVERY_SCANLINE_IRQ
    ; Set VADDR to 0x0000 to prevent ESI IRQs, and acknowledge any pending ESI-IRQs
    bit PPUSTATUS
    lda #0
    sta PPUADDR
    sta PPUADDR
    lda *__vbl_isr_mapper_config
    sta CFG_REG
.endif

    ; Select deferred-isr buffer to read from
    ldy #0
    lda __lcd_isr_num_calls
    bit __lcd_isr_read_buf
    bpl 0$
    ldy #.MAX_DEFERRED_ISR_CALLS
    lda __lcd_isr_num_calls+1
0$:
    sty *__ESI_write_index
    sta __lcd_isr_buf_length

    ; Set scroll address
    lda __lcd_isr_scroll_x,y
    sta PPUSCROLL
    lda __lcd_isr_scroll_y,y
    sta PPUSCROLL
    lda *0x00
  
    ; Write PPUCTRL and force NMI enabled to avoid deadlock from buggy isr handlers
    lda __lcd_isr_PPUCTRL,y
    ;lda *_shadow_PPUCTRL
    ora #0x80
    sta PPUCTRL

    ; Write PPUMASK, in case it was disabled
    lda __lcd_isr_PPUMASK,y
    sta PPUMASK

    ; Call fake LCD isr if present (0x60 = RTS means no LCD) and
    lda .jmp_to_LCD_isr
    cmp #0x60
    beq __crt0_NMI_skip
.ifne GBDK_NES_EVERY_SCANLINE_IRQ
    ; Setup IRQ for LCD isr
    inc *__ESI_write_index
    beq 9$
    ldx *__vbl_isr_mapper_config
    jsr SetupNextLCD
    cli
9$:
.else
    ; First delay until end-of-vblank, depending on transfer buffer contents...
    ; (X set to correct delay value by DoUpdateVRAM)
1$:
    lda *0x00
    dex
    bne 1$
    ; Do additional delay of 5186 cycles if running on a PAL system, and -5*7 + 2 = -33 for alignment
    ; This is to compensate for the longer vblank period of 7459 vs NTSC's 2273
    bit *__SYSTEM
    bvc 2$
    nop
    nop
    ldy #5
    ldx #(14-7)
3$:
    dex
    bne 3$
    dey
    bne 3$
2$:
    ; Call the write reg subroutine
    jsr .do_lcd_ppu_reg_writes
.endif
__crt0_NMI_skip:

    ;
    jsr .jmp_to_TIM_isr
    ;

    ; Update frame counter
    lda *_sys_time
    clc
    adc #1
    sta *_sys_time
    lda *(_sys_time+1)
    adc #0
    sta *(_sys_time+1)

    ; Restore current bank
    lda *__current_bank
    tay
    sta .identity,y

    pla
    tay
    pla
    tax
    pla
    rti

DoUpdateVRAM:
    WRITE_PALETTE_SHADOW
    bit *__vram_transfer_buffer_valid
    bmi DoUpdateVRAM_drawListValid
DoUpdateVRAM_drawListInvalid:
    ; Delay for all unused cycles and ProcessDrawList overhead to keep timing consistent
    lda *0x00
    nop
    ldx #(VRAM_DELAY_CYCLES_X8+6)
    bne DoUpdateVRAM_end
DoUpdateVRAM_drawListValid:
    jsr ProcessDrawList
    ; Delay for remaining unused cycles to keep timing consistent
    ldx *__vram_transfer_buffer_num_cycles_x8
    ; Reset available cycles to initial value
    lda #VRAM_DELAY_CYCLES_X8
    sta *__vram_transfer_buffer_num_cycles_x8
DoUpdateVRAM_end:
    rts

__crt0_setPalette:
    ; Set background color to 30 (white)
    lda #0x30
    sta __crt0_paletteShadow
    ; set all background / sprite sub-palettes to 10, 00, 1D
    ldx #0x18
1$:
    lda #0x1D
    sta __crt0_paletteShadow,x
    dex
    lda #0x00
    sta __crt0_paletteShadow,x
    dex
    lda #0x10
    sta __crt0_paletteShadow,x
    dex
    bne 1$
    rts

;
; Waits for vblank flag to be set. This macro should only be
; used during the PPU warm-up phase at reset, as a hardware 
; flaw can cause the flag to be cleared in the register
; without returning a set flag on the CPU data bus.
;
; On Dendy-like Famiclones there is an additional problem
; that this pathological case can occur *every* frame if the wait
; loop is exactly 8 cycles long, causing a soft-lock at reset.
; For this reason, code before the "bpl .loop" instruction must 
; be aligned so the branch does not cross a 256-byte page.
;
; https://www.nesdev.org/wiki/PPU_power_up_state
;
.macro CRT0_WAIT_PPU ?.loop;
.loop:
    lda PPUSTATUS
    bpl .loop
.endm

;
; Detects system. After execution, A contains the following values:
;
; 0: NTSC NES/Famicom
; 1: PAL NES
; 2: Dendy-like Famiclone
;
.macro CRT0_WAIT_PPU_AND_DETECT_SYSTEM ?.loop, ?.end_of_loop, ?.end
    ldx #0
    ldy #0
; 256 iterations of the inner loop (X) takes 256 * (4 + 2 + 2 + 3) - 1 = 2816 cycles
; 1 iteration of the outer loop takes 2816 + 2 + 3 = 2821 cycles
; And different systems will have the following contents in Y:
; NTSC:   29780 / 2821 = 10
; PAL:    33247 / 2821 = 11
; Dendy:  35464 / 2821 = 12
.loop:
    bit PPUSTATUS
    bmi .end_of_loop
    inx
    bne .loop
    iny
    bne .loop
.end_of_loop:
    tya
    sec
    sbc #10
.end:
.endm

.macro CRT0_CLEAR_RAM
    ; Clear WRAM
    lda #>0x6000
    sta *REGTEMP+1
    lda #<0x6000
    sta *REGTEMP
    tay
__crt0_clearWRAM_loop:
    sta [*REGTEMP],y
    iny
    bne __crt0_clearWRAM_loop
    inc *REGTEMP+1
    bpl __crt0_clearWRAM_loop
    ; Clear console RAM
    ldx #0x00
    txa
__crt0_clearRAM_loop:
    sta 0x0000,x
    sta 0x0100,x
    sta 0x0200,x
    sta 0x0300,x
    sta 0x0400,x
    sta 0x0500,x
    sta 0x0600,x
    sta 0x0700,x
    inx
    bne __crt0_clearRAM_loop
.endm

__crt0_clearVRAM:
    lda #0x00
    tax
    ldy #0x10
__crt0_clearVRAM_hi_addr_A:
    sta PPUADDR
    lda #0x00
    sta PPUADDR
    txa
    ldx #0
__crt0_clearVRAM_loop:
    sta PPUDATA
    dex
    bne __crt0_clearVRAM_loop
    dey
    bne __crt0_clearVRAM_loop
    rts

.ifne GBDK_NES_EVERY_SCANLINE_IRQ
__crt0_clearAT:
    ldy #7
1$:
    sty CFG_REG
    tya
    pha
    lda #0x0F
    ldy #1
    ldx #0xFF
    jsr __crt0_clearVRAM_hi_addr_A 
    pla
    tay
    dey
    bpl 1$
    lda #0
    sta CFG_REG
    rts
.endif

.wait_vbl_done::
_wait_vbl_done::
_vsync::

    .define .lcd_scanline_previous "REGTEMP"
    .define .lcd_num_calls "REGTEMP+1"
    .define .lcd_buf_end "REGTEMP+2"
    .define .plus_one_flag "REGTEMP+3"

    jsr _flush_shadow_attributes
    
    ; Save shadow registers that VBL or LCD isr could change
    lda *_shadow_PPUMASK
    pha
    lda *_shadow_PPUCTRL
    pha
    lda *_bkg_scroll_x
    pha
    lda *_bkg_scroll_y
    pha
    lda *__vram_transfer_mapper_bits
    pha
    
    ; Allow VBL isr to modify shadow registers if present
    jsr .jmp_to_VBL_isr

    ; Set initial scanline value
    lda #0xFF
    sta *.lcd_scanline_previous
    ; Init +0/+1 bits for simulated Y-increment between calls
    lda #0x7F
    sta *.plus_one_flag

    ldy #0
    lda #.MAX_DEFERRED_ISR_CALLS
    bit __lcd_isr_read_buf
    bmi 8$
    ldy #.MAX_DEFERRED_ISR_CALLS
    lda #(2*.MAX_DEFERRED_ISR_CALLS)
8$:
    sty *.lcd_num_calls
    sta *.lcd_buf_end

    ; Special-case: LCD at scanline 0 should just directly replace first entry
    lda *__lcd_scanline
    bne 0$
    jsr .jmp_to_LCD_isr
    lda #0xFF
    sta *.lcd_scanline_previous
0$:

    ; Write shadow registers as first LCD entry (VBL and LCD at scanline 0 are equal)
    ldy *.lcd_num_calls
    jsr .write_shadow_registers_to_buffer
    iny
    sty *.lcd_num_calls

    lda *__vram_transfer_mapper_bits
    sta *__vbl_isr_mapper_config

    lda *.lcd_scanline_previous

    jmp 2$
1$:
    pla
    sta *.lcd_scanline_previous
2$:
    ; We are done if next scanline is <= the previous one
    cmp #0xFF
    beq 3$
    cmp *__lcd_scanline
    bcs _wait_vbl_done_waitForNextFrame
3$:
    ;
    ldy *.lcd_num_calls
    lda *__lcd_scanline
    ; We are done if next LCD scanline >= SCREENHEIGHT
    cmp #.SCREENHEIGHT
    bcs _wait_vbl_done_waitForNextFrame
    pha
    clc ; -1 to compensate for LCD PPU write taking up a scanline on its own
    sbc *.lcd_scanline_previous
    sta __lcd_isr_delay_num_scanlines,y
    ; Add number of delayed scanlines+1 to _bkg_scroll_y to simulate PPU increment
    ; (but old _bkg_scroll_y needs to be treated as -1 in first simulated-PPU-increment)
    asl *.plus_one_flag
    adc *_bkg_scroll_y
    sta *_bkg_scroll_y
    ; Call LCD isr
    jsr .jmp_to_LCD_isr
    jsr .write_shadow_registers_to_buffer
       
    iny
    sty *.lcd_num_calls
    cpy *.lcd_buf_end
    bne 1$
    
    ; Clear last-scanline-value from stack
    pla

_wait_vbl_done_waitForNextFrame:
    lda *.lcd_num_calls
    ldy #0
    bit __lcd_isr_read_buf
    bmi 10$
    iny
10$:
    sta __lcd_isr_num_calls,y
    
    ; Flip read buf atomically
    lda __lcd_isr_read_buf
    eor #0x80
    sta __lcd_isr_read_buf
    ; Enable OAM DMA in next NMI
    sec
    ror *__crt0_spritePageValid
    ; Restore shadow registers
    pla
    sta *__vram_transfer_mapper_bits
    pla
    sta *_bkg_scroll_y
    pla
    sta *_bkg_scroll_x
    pla
    sta *_shadow_PPUCTRL
    pla
    sta *_shadow_PPUMASK

    lda *_sys_time
_wait_vbl_done_waitForNextFrame_loop:
    cmp *_sys_time
    beq _wait_vbl_done_waitForNextFrame_loop

    ; Disable OAM DMA in next NMI
    clc
    ror *__crt0_spritePageValid

    ;
    lda *_sys_time
    sta *_sys_time_old
    ;
    rts

.write_shadow_registers_to_buffer:
    ; Copy shadow registers
    ldy *.lcd_num_calls
    lda *_shadow_PPUMASK
    sta __lcd_isr_PPUMASK,y
    lda *_shadow_PPUCTRL
    sta __lcd_isr_PPUCTRL,y
    lda *_bkg_scroll_x
    sta __lcd_isr_scroll_x,y
    lsr
    lsr
    lsr
    sta __lcd_isr_ppuaddr_lo,y
    lda *_bkg_scroll_y
    sta __lcd_isr_scroll_y,y
    and #0xF8
    asl
    asl
    ora __lcd_isr_ppuaddr_lo,y
    sta __lcd_isr_ppuaddr_lo,y
    lda *__vram_transfer_mapper_bits
    sta __lcd_isr_mapper_config,y
    rts

.display_off::
_display_off::
    lda *_shadow_PPUMASK
    and #~(PPUMASK_SHOW_BG | PPUMASK_SHOW_SPR)
    sta *_shadow_PPUMASK
    sta PPUMASK
    ; Set forced blanking bit
    sec
    ror *.crt0_forced_blanking
    rts

.display_on::
_display_on::
    lda *_shadow_PPUMASK
    ora #(PPUMASK_SHOW_BG | PPUMASK_SHOW_SPR)
    sta *_shadow_PPUMASK
    ; Clear forced blanking bit
    clc
    ror *.crt0_forced_blanking
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
    sta __crt0_RESET_bankSwitchValue+1
    sta CFG_REG
    ; Disable NMIs and rendering
    sta PPUCTRL
    sta PPUMASK
    ; Clear RAM
    CRT0_CLEAR_RAM
    ; Wait for PPU warm-up / detect system
    bit PPUSTATUS
    CRT0_WAIT_PPU
    CRT0_WAIT_PPU_AND_DETECT_SYSTEM
    ; Store system in upper two bits of __SYSTEM, to allow bit instruction to quickly test for PAL
    clc
    ror
    ror
    ror
    sta *__SYSTEM
    ; Clear VRAM
    jsr __crt0_clearVRAM
    jsr __crt0_clearAT
    ; Hide sprites in shadow OAM, and perform OAM DMA
    ldx #0
    txa
    jsr _hide_sprites_range
    stx OAMADDR
    lda #>_shadow_OAM
    sta OAMDMA

    ; Perform initialization of DATA area
    lda #<s__XINIT
    sta ___memcpy_PARM_2
    lda #>s__XINIT
    sta ___memcpy_PARM_2+1
    lda #<l__XINIT
    sta ___memcpy_PARM_3
    lda #>l__XINIT
    sta ___memcpy_PARM_3+1
    lda #<s__DATA
    ldx #>s__DATA
    jsr ___memcpy
    lda #>0x2000
    sta __vram_transfer_ppu_hi_mask

    ; Set bank to first
    lda #0x00
    sta *__current_bank
    ; Set palette shadow
    jsr __crt0_setPalette
    lda #VRAM_DELAY_CYCLES_X8
    sta *__vram_transfer_buffer_num_cycles_x8
    lda #0
    sta *__vram_transfer_buffer_pos_w
    ; 
    lda #(PPUMASK_SHOW_BG | PPUMASK_SHOW_SPR | PPUMASK_SHOW_BG_LC | PPUMASK_SHOW_SPR_LC)
    sta *_shadow_PPUMASK
    lda #0x80
    sta *__crt0_spritePageValid
    ; enable NMI
    lda #(PPUCTRL_NMI | PPUCTRL_SPR_CHR)
    sta *_shadow_PPUCTRL
    sta PPUCTRL
    ; Turn off frame IRQ to avoid clashes with every-scanline-IRQ
    lda #0xC0
    sta 0x4017
    ; Enable IRQs
    cli
    ; Call main
    jsr _main
    ; main finished - loop forever
__crt0_waitForever:
    jmp __crt0_waitForever

.ifeq GBDK_NES_EVERY_SCANLINE_IRQ
;
; Use timed code for LCD ISR PPU register writes
;
.do_lcd_ppu_reg_writes:
    .define .reg_write_index    "__crt0_NMITEMP+1"
    .define .lda_PPUADDR        "__crt0_NMITEMP+2"
    .define .ldx_PPUMASK        "__crt0_NMITEMP+3"
    
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    ; Skip if empty buffer (no calls were made within frame)
    lda __lcd_isr_buf_length
    beq 2$

    ldy #0
    sty *.acc
1$:
    sty *.reg_write_index
    ldx __lcd_isr_delay_num_scanlines,y
    beq 3$
    jsr .delay_to_lcd_scanline
3$:
    ldy *.reg_write_index
    

    ; Pre-write PPUADDR (1st write) and y-scroll
    sty PPUADDR
    lda __lcd_isr_scroll_y,y
    sta PPUSCROLL
    ; A <- PPUADDR (2nd write)
    lda __lcd_isr_ppuaddr_lo,y    ; lda __lcd_isr_scroll_x,y
    sta *.lda_PPUADDR
    ; ldx <- mapper_config
    ldx __lcd_isr_mapper_config,y
    stx *.ldx_mapper_config
    ; ldx <- PPUMASK
    ldx __lcd_isr_PPUMASK,y
    stx *.ldx_PPUMASK
    ; X <- SCROLLX
    ldx __lcd_isr_scroll_x,y
    ; Y <- PPUCTRL
    lda __lcd_isr_PPUCTRL,y
    tay
    lda *.lda_PPUADDR
    ;
    ; Write 4 PPU registers in following order.
    ;
    ; 1. PPUSCROLL          (needs to be written to set fine-x)
    ; 2. PPUADDR 2nd write  (highest priority as needs to happen before the two-tile pre-fetch) 
    ; 3. PPUCTRL            (PPU pattern table switch can affect two-tile pre-fetch)
    ; 4. PPUMASK            (emphasis and render on/off are maybe less distracting?)
    ;
    ; TODO: Self-modifying code could build a non-redundant write sequence in RAM.
    ;
    stx PPUSCROLL
    sta PPUADDR
    ;lax *.ldx_mapper_config
    ;.db 0xA7, <.ldx_mapper_config
    ;txa
    sta ;.identity,x
    lda *.ldx_mapper_config
    sta CFG_REG
    ldx *.ldx_PPUMASK
    stx PPUMASK
    sty PPUCTRL

    sta __CFG_REG_cache

    ; Delay for 40.666 NTSC cycles / 33.5625 PAL cycles
    jsr .delay_fractional
    ldy *.reg_write_index
    
    ; Finally, write Y-scroll part of T with original non-LCD shadow values, but 
    ; *without* triggering an update of V, to mitigate glitches on lag frames.
    ; In normal circumstances, NMI will re-write T with the new proper Y-scroll 
    ; value for start of screen. Or the next iteration of this loop may overwrite
    ; it as well.
    ; But if our calls to VBL/LCD handlers disable NMI just at the wrong moment in
    ; the vsync routine, and cause the scroll update in NMI to be skipped, 
    ; this mitigation will leave T with a "reasonable" value of the old shadow 
    ; bkg scroll register for Y at scanline 0.
    ;NOP
    ;NOP
    lda *.ldx_mapper_config
    
    sty PPUADDR
    lda *_bkg_scroll_y
    sta PPUSCROLL

    iny
    cpy __lcd_isr_buf_length
    bne 1$
2$:
    rts

__crt0_IRQ:
    jmp __crt0_IRQ
.else
;
; Use every-scanline-IRQ for LCD ISR PPU register writes
;
SetupNextLCD:
    .define .lda_PPUADDR        "__crt0_NMITEMP+2"
    .define .ldx_PPUMASK        "__crt0_NMITEMP+3"
    ; Skip if empty buffer (no calls were made within frame)
    lda __lcd_isr_buf_length
    beq 3$
    
    ldy *__ESI_write_index
    cpy __lcd_isr_buf_length
    beq 3$
    
    lda __lcd_isr_delay_num_scanlines,y
    beq 4$
    sta *__ESI_scanline_counter
2$:
    ; At least one more split - enable every-scanline-IRQ
    txa
    ora #CFG_IRQ_ENABLE
    sta __CFG_REG_cache
    sta CFG_REG
    rts

3$:
    ; No more splits - turn off every-scanline-IRQ
    txa
    and #~CFG_IRQ_ENABLE
    sta __CFG_REG_cache
    sta CFG_REG
    lda #0xFF ; Return non-zero result to avoid looping back to hblank writes
    rts

4$:
    rts

__crt0_IRQ:
    dec *__ESI_scanline_counter
    beq __crt0_IRQ_reached_scanline
    ; Acknowledge IRQ by writing CFG_REG
    sta *__crt0_NMITEMP+2
    lda *__CFG_REG_cache
    sta CFG_REG
    lda *__crt0_NMITEMP+2
    rti
__crt0_IRQ_reached_scanline:
    pha
    txa
    pha
    tya
    pha

    ldy *__ESI_write_index
    
    lda __lcd_isr_PPUCTRL,y
    bpl __crt0_IRQ_is_palette_rewrite

    ldx #4
1$:
    dex
    bne 1$
    nop

__crt0_IRQ_reached_scanline_write_scroll:
    ; Pre-write PPUADDR (1st write) and y-scroll
    sty PPUADDR
    lda __lcd_isr_scroll_y,y
    sta PPUSCROLL
    ; A <- PPUADDR (2nd write)
    lda __lcd_isr_ppuaddr_lo,y
    sta *.lda_PPUADDR
    ; ldx <- mapper_config
    ldx __lcd_isr_mapper_config,y
    stx *.ldx_mapper_config
    ; ldx <- PPUMASK
    ldx __lcd_isr_PPUMASK,y
    stx *.ldx_PPUMASK
    ; X <- SCROLLX
    ldx __lcd_isr_scroll_x,y
    ; Y <- PPUCTRL
    lda __lcd_isr_PPUCTRL,y
    tay
    lda *.lda_PPUADDR
    ;
    ; Write 4 PPU registers in following order.
    ;
    ; 1. PPUSCROLL          (needs to be written to set fine-x)
    ; 2. PPUADDR 2nd write  (highest priority as needs to happen before the two-tile pre-fetch) 
    ; 3. PPUCTRL            (PPU pattern table switch can affect two-tile pre-fetch)
    ; 4. PPUMASK            (emphasis and render on/off are maybe less distracting?)
    ;
    ; TODO: Self-modifying code could build a non-redundant write sequence in RAM.
    ;
    stx PPUSCROLL
    sta PPUADDR
    sty PPUCTRL
    ldx *.ldx_mapper_config
    stx CFG_REG
    lda *.ldx_PPUMASK
    sta PPUMASK

    inc *__ESI_write_index
    jsr SetupNextLCD
    beq __crt0_IRQ_reached_scanline_write_scroll

    pla
    tay
    pla
    tax
    pla
    rti

__crt0_IRQ_is_palette_rewrite:
    .define .zp         "__crt0_NMITEMP"
    ; Check if this was the NOP-slide being interrupted

    tax
    bit *__inside_nop_slide
    bmi 10$
    jmp __crt0_IRQ_is_palette_rewrite_setup_NOP_slide
10$:
    ;txa
    and #0x3F
    ora #0x80

    lsr *__inside_nop_slide

    sta *.zp
    ora #0x04
    sta PPUCTRL
 
    ; pop redundant nop-slide return address / flags / pushed-registers from stack
    tsx
    txa
    clc
    adc #6
    tax
    txs
    ; -> 12 cycles
    
    bit *__SYSTEM
    bvs 3$
    nop ; NTSC fractional cycle count
    nop
    nop
    nop
    NOP ; Extra NOP - seems to be needed for added timing
3$:             ; -> 15 NTSC cycles / 6 PAL cycles

    lda *.zp ; timing
    nop 

    ; --- Wait for next hblank
    ; ...

    ldx __lcd_isr_pal_c0,y
    ldy #0x3F
    sty PPUADDR

    lda #0x00
    ldy #0x3F
    sta PPUADDR

    sty PPUADDR
    ldy #0xFC
    lda #0x10
    sta PPUMASK
    lda #0x00

    sta PPUMASK
    stx PPUDATA     ; write BG0

    ; Delay over next scanline to reach next hblank, while PPU outputs BG0
    ; ...
        
    sty PPUADDR
    
    lda *.zp
    sta PPUCTRL

    ; Set VADDR to third sub-palette at 3F0C
    lda #>0x3F0C
    sta PPUADDR
    lda #0xFF
    sta PPUSCROLL
    lda #0xE0
    sta PPUSCROLL
    lda #<0x3F0C
    sta PPUADDR

    NOP
    NOP
    NOP

    bit *__SYSTEM
    bvs 4$
    nop
    nop
    nop
    nop
4$:             ; -> 13 NTSC cycles / 6 PAL cycles

    ldy *__ESI_write_index

    lda __lcd_isr_mapper_config+1,y
    sta CFG_REG

    ;nop ; tsx
    stx *.zp+1 ; timing
    
    ldx __lcd_isr_PPUMASK+1,y
    stx *.zp ;timing
    nop

    lda __lcd_isr_pal_c3,y
    ldx __lcd_isr_pal_c2,y
    sta *.zp
    lda __lcd_isr_pal_c1,y
    tay
    lda *.zp
    ;
    bit PPUDATA
    sty PPUDATA
    stx PPUDATA
    sta PPUDATA
    
    ldx *.zp+1 ; timing
    
    ; Finally, wait for another hblank to get enough time to write scroll coordinates
    NOP
    bit *__SYSTEM
    bvs 5$
    nop
    nop
    nop
    nop
5$:             ; -> 13 NTSC cycles / 6 PAL cycles

    inc *__ESI_write_index
    ldy *__ESI_write_index
    
    jmp __crt0_IRQ_reached_scanline_write_scroll

__crt0_IRQ_is_palette_rewrite_setup_NOP_slide:
    ; Set flag to indicate next IRQ has NOP-slide completed
    nop
    sec
    ror *__inside_nop_slide
    
    ; First acknowledge IRQ by writing CFG_REG
    lda *__CFG_REG_cache
    sta CFG_REG
    ; Then delay, and finally enter nop-slide
    lda #1
    sta *__ESI_scanline_counter
    cli

    ldx #7
0$:
    dex
    bne 0$
    nop

    NOP
    NOP
    NOP
    ; If something goes wrong, loop here forever
1$:
    jmp 1$

.endif

__add_palette_rewrite::
    ;.define .lcd_num_calls "REGTEMP+1"

    ldy *.lcd_num_calls
    sta __lcd_isr_pal_c0,y
    sta *__textbox_backdrop
    txa
    sta __lcd_isr_pal_c1,y
    lda *__add_palette_rewrite_PARM_3
    sta __lcd_isr_pal_c2,y
    lda *__add_palette_rewrite_PARM_4
    sta __lcd_isr_pal_c3,y
    lda *_shadow_PPUCTRL ;#0x00
    and #0x3F
    sta __lcd_isr_PPUCTRL,y
    lda *_shadow_PPUMASK
    sta __lcd_isr_PPUMASK,y
    iny
    lda #0
    sta __lcd_isr_delay_num_scanlines,y
    sty *.lcd_num_calls
    rts

; Interrupt / RESET vector table
.area VECTORS (ABS)
.org 0xfffa
.dw	__crt0_NMI
.dw	__crt0_RESET
.dw	__crt0_IRQ
