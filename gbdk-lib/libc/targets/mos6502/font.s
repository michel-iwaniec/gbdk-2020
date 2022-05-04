; font.ms
;
;       Michael Hope, 1999
;       michaelh@earthling.net
;       Distrubuted under the Artistic License - see www.opensource.org
;
        .include        "global.s"

        .area	OSEG (PAG, OVR)
        _temp_word:                 .ds 2

        .globl  .cr_curs
        .globl  .adv_curs
        .globl  .cury, .curx
        .globl  .display_on, .display_off

        ; Structure offsets
        sfont_handle_sizeof     = 3
        sfont_handle_font       = 1
        sfont_handle_first_tile = 0

        ; Encoding types - lower 2 bits of font
        FONT_256ENCODING        = 0
        FONT_128ENCODING        = 1
        FONT_NOENCODING         = 2

        ; Other bits
        FONT_COMPRESSED         = 4
        FONT_BCOMPRESSED        = 2
        
        .CR                     = 0x0A          ; Unix
        .SPACE                  = 0x00

        ; Maximum number of fonts
        .MAX_FONTS              = 6

        .area   _FONT_HEADER (ABS)

        .org    .MODE_TABLE+4*.T_MODE
        jmp     .tmode

        .module font.ms

        ;.globl  .fg_colour, .bg_colour

        ;.globl  .drawing_vbl, .drawing_lcd
        ;.globl  .int_0x40, .int_0x48
        ;.globl  .remove_int
        .globl  _set_bkg_1bpp_data, _set_bkg_data

        .area   BSS ;_INITIALIZED
.curx::                         ; Cursor position
        .ds     0x01
.cury::
        .ds     0x01

        .area   _INITIALIZER
        .db     0x00            ; .curx
        .db     0x00            ; .cury

        .area   BSS ;_DATA
        ; The current font
font_handle_base:
font_current::
        .ds     sfont_handle_sizeof
        ; Cached copy of the first free tile
font_first_free_tile::
        .ds     1
        ; Table containing descriptors for all of the fonts
font_table::
        .ds     sfont_handle_sizeof*.MAX_FONTS

        .area   _HOME

_font_load_ibm::
        lda #<_font_ibm
        ldx #>_font_ibm
        jmp font_load
        rts

; Load the font HL
font_load::
        sta *_temp_word
        stx *_temp_word+1
        ; += 128+3
        clc
        adc #(128+3)
        sta _set_bkg_1bpp_data_PARM_3
        txa
        adc #0
        sta _set_bkg_1bpp_data_PARM_3+1

        jsr .display_off

        ; numTiles
        ldy #1
        lda [*_temp_word],y
        tax

        ;
        lda #0x20   ; TODO: How to obtain starting tile?...
        ldx #0xE0
        ;
        ;jsr _set_bkg_1bpp_data
        ;jsr .display_on
        ;
        ;rts

;        call    .display_off
;        push    hl
;
;        ; Find the first free font entry
        ldy #sfont_handle_font                  ;        ld      hl,#font_table+sfont_handle_font
        ldx #.MAX_FONTS                         ;        ld      b,#.MAX_FONTS
font_load_find_slot:
        lda font_table,y                        ;        ld      a,(hl)          ; Check to see if this entry is free
        iny                                     ;        inc     hl              ; Free is 0000 for the font pointer
        ora font_table,y                        ;        or      (hl)
                                                ;        cp      #0
        beq font_load_found                     ;        jr      z,font_load_found

        iny                                     ;        inc     hl
        iny                                     ;        inc     hl
        dex                                     ;        dec     b
        bne font_load_find_slot                 ;        jr      nz,font_load_find_slot
                                                ;        pop     hl
                                                ;        ld      hl,#0
        jmp font_load_exit                      ;        jr      font_load_exit  ; Couldn't find a free space
font_load_found:
;                                               ; HL points to the end of the free font table entry
        lda *_temp_word+1                       ;        pop     de
        sta font_table,y                        ;        ld      (hl),d          ; Copy across the font struct pointer
        dey                                     ;        dec     hl
        lda *_temp_word
        sta font_table,y                        ;        ld      (hl),e

        lda font_first_free_tile                ;        ld      a,(font_first_free_tile)
        dey                                     ;        dec     hl
        sta font_table,y                        ;        ld      (hl),a          
;
                                                ;        push    hl
        jsr font_set                            ;        call    font_set        ; Set this new font to be the default
        tya
        pha
;        ; Only copy the tiles in if were in text mode
        lda .mode                               ;       ld      a,(.mode)
        and #.T_MODE                            ;       and     #.T_MODE
        beq font_load_skip_copy_current
        jsr font_copy_current                   ;       call    nz,font_copy_current
font_load_skip_copy_current:
; Increase the 'first free tile' counter
        lda #<font_current+sfont_handle_font    ;       ld      hl,#font_current+sfont_handle_font
        sta .tmp
        lda #>font_current+sfont_handle_font
        sta .tmp+1
        ldy #0
        lda [*.tmp],y                           ;       ld      a,(hl+)
        iny
        tax
        lda [*.tmp],y                           ;       ld      h,(hl)
        sta .tmp+1
        stx .tmp                                ;        ld      l,a
                                                ;        inc     hl              ; Number of tiles used
        lda font_first_free_tile                ;        ld      a,(font_first_free_tile)
        clc
        adc [*.tmp],y                           ;        add     a,(hl)
        sta font_first_free_tile                ;        ld      (font_first_free_tile),a
font_load_exit:
;        ;; Turn the screen on
        jsr .display_on
;        LDH     A,(.LCDC)
;        OR      #(LCDCF_ON | LCDCF_BGON)
;        AND     #~(LCDCF_BG9C00 | LCDCF_BG8000)
;        LDH     (.LCDC),A
;
        pla                                     ;        pop     hl              ; Return font setup in HL
        rts                                     ;        RET

        ; Copy the tiles from the current font into VRAM
font_copy_current::
        ; Find the current font data
        lda font_current+sfont_handle_font      ;        ld      hl,#font_current+sfont_handle_font
        sta *.tmp                               ;        ld      a,(hl+)
        lda font_current+sfont_handle_font+1    ;        ld      h,(hl)
        sta *.tmp+1                             ;        ld      l,a
        ldy #0
        lda [*.tmp],y                           ;        ld      a, (hl+)
        iny
        pha                                     ;        ld      e, a
        lda [*.tmp],y                           ;        ld      a, (hl+)
        iny
        tax                                     ;        ld      d, a
;
        pla                                     ;        ld      a, e
        pha
                                                ;        ld      c, #128
        and #3                                  ;        and     #3
        cmp #FONT_128ENCODING                   ;        cp      #FONT_128ENCODING
        beq 1$                                  ;        jr      z, 1$
        cmp #FONT_NOENCODING                    ;        cp      #FONT_NOENCODING
        beq 2$                                  ;        jr      z, 2$
        ; 256ENCODING - add #256 to .tmp -> inc .tmp+1
        inc .tmp+1                              ;        inc     h
        jmp 2$                                  ;        jr      2$
1$:
        ; 128ENCODING - add #128 to y
;        ld      a, c
;        add     l
;        ld      l, a
;        adc     h
;        sub     l
;        ld      h, a
        tya
        ora #128
        tay
2$:

        ;        push    hl
        ;        ld      c, e
        pla
                                        ;        push    de
        and #FONT_COMPRESSED            ;        bit     FONT_BCOMPRESSED, c
        bne 3$                          ;        jr      nz, 3$
        
;        ld      a, (font_current+sfont_handle_first_tile)
;        ld      e, a



;        call    _set_bkg_data
                    ;        jr      4$
        rts
3$:
        tya
        clc
        adc *.tmp
        sta *_set_bkg_1bpp_data_PARM_3
        lda *.tmp+1
        adc #0
        sta *_set_bkg_1bpp_data_PARM_3+1
        lda font_current+sfont_handle_first_tile
        jsr _set_bkg_1bpp_data      ;        call    _set_bkg_1bpp_data
;4$:
;        add     sp, #4
;        ret
        jsr .display_on
        rts

;        ; Set the current font to HL
font_set::
        lda font_table,y            ;        ld      a,(hl+)
        iny
        sta font_current            ;        ld      (font_current),a
        lda font_table,y            ;        ld      a,(hl+)
        iny
        sta font_current+1          ;        ld      (font_current+1),a
        lda font_table,y            ;        ld      a,(hl+)
        iny
        sta font_current+2          ;        ld      (font_current+2),a
        dey
        dey
        dey
        rts

        ;; Print a character with interpretation
.put_char::
;        ; See if it's a special char
        cmp #.CR                                    ;        cp      #.CR
        bne 1$                                      ;        jr      nz,1$

; Now see if were checking special chars
                                                    ;        push    af
        lda .mode                                   ;        ld      a,(.mode)
        and #.M_NO_INTERP                           ;        and     #.M_NO_INTERP
        bne 2$                                      ;        jr      nz,2$
        jsr .cr_curs                                ;        call    .cr_curs
                                                    ;        pop     af
        rts                                         ;        ret

2$:
                                                    ;        pop     af
1$:
        jsr .set_char                               ;        call    .set_char
        jmp .adv_curs                               ;        jp      .adv_curs

        ;; Print a character without interpretation
.out_char::
        jsr .set_char                               ;        call    .set_char
        jmp .adv_curs                               ;        jp      .adv_curs

        ;; Delete a character
.del_char::
        jsr .rew_curs                               ;        call    .rew_curs
        lda #.SPACE                                 ;        ld      a,#.SPACE
        jmp .set_char                               ;        jp      .set_char

        ;; Print the character in A
.set_char:
        pha                                     ;        push    af
        lda font_current+2                      ;        ld      a,(font_current+2)
; Must be non-zero if the font system is setup (cant have a font in page zero)
                                                ;        or      a
        bne 3$                                  ;        jr      nz,3$

        ; Font system is not yet setup - init it and copy in the ibm font
        ; Kind of a compatibility mode
        jsr _font_init                          ;        call    _font_init
        
        ; Need all of the tiles
        lda #0                                  ;        xor     a
        sta font_first_free_tile                ;        ld      (font_first_free_tile),a

        jsr _font_load_ibm                      ;        call    _font_load_ibm
3$:
                                                ;        push    de
                                                ;        push    hl
; Compute which tile maps to this character
        pla
        pha
        tax
                                                ;        ld      e,a
                                                ;        ld      hl,#font_current+sfont_handle_font
        lda font_current+sfont_handle_font      ;        ld      a,(hl+)
        sta *.tmp
        lda font_current+sfont_handle_font+1    ;        ld      h,(hl)
        sta *.tmp+1                             ;        ld      l,a
        ldy #0
        lda [*.tmp],y                           ;        ld      a,(hl+)
        and #3                                  ;        and     #3
        cmp #FONT_NOENCODING                    ;        cp      #FONT_NOENCODING
        beq set_char_no_encoding                ;        jr      z,set_char_no_encoding
                                                ;        inc     hl
        iny
        iny
; Now at the base of the encoding table
; E is set above
        pla                                     ;        pop     af
        pha
        clc
        adc .identity,y
        tay
                                                ;        ld      d,#0
                                                ;        add     hl,de
        lda [*.tmp],y                           ;        ld      e,(hl)          ; That's the tile!
        tax
set_char_no_encoding:
        pla
        txa
        clc
        adc font_current+sfont_handle_first_tile
                                                ;        ld      e,a
        ldx .curx                               ;        LD      A,(.cury)       ; Y coordinate
        ldy .cury                               ;        LD      L,A
        jsr .writeNametableByte                 ;        LD      H,#0x00
                                                ;        ADD     HL,HL
                                                ;        ADD     HL,HL
                                                ;        ADD     HL,HL
                                                ;        ADD     HL,HL
                                                ;        ADD     HL,HL
                                                ;        LD      A,(.curx)       ; X coordinate
                                                ;        LD      C,A
                                                ;        LD      B,#0x00
                                                ;        ADD     HL,BC
                                                ;        LD      BC,#0x9800
                                                ;        ADD     HL,BC

                                                ;        WAIT_STAT

                                                ;        LD      (HL),E
                                                ;        POP     HL
                                                ;        POP     DE
                                                ;        POP     BC
        rts                                     ;        RET


_putchar::
                                ;   PUSH    BC
                                ;   LDA     HL,4(SP)        ; Skip return address
                                ;   LD      A,(HL)          ; A = c
        jsr .put_char           ;   CALL    .put_char
                                ;   POP     BC
        rts                     ;   RET

_setchar::
                                ;        PUSH    BC
                                ;        LDA     HL,4(SP)        ; Skip return address
                                ;        LD      A,(HL)          ; A = c
        jsr .set_char           ;        CALL    .set_char
                                ;        POP     BC
                                ;        RET
        rts

_font_load::
        jsr font_load
        rts

_font_set::
        tay
                                ;        push    bc
                                ;        LDA     HL,4(SP)        ; Skip return address
                                ;        LD      A,(HL)          ; A = c
                                ;        inc     hl
                                ;        ld      h,(hl)
                                ;        ld      l,a
        jsr font_set            ;        call    font_set
                                ;        pop     bc
                                ;        ld      de,#0           ; Always good...
                                ;        ret
        rts

_font_init::
                                                ;        push    bc
        .globl  .tmode
;
        jsr .tmode                              ;        call    .tmode
;
        lda #0                                  ;        xor     a
        sta font_first_free_tile                ;        ld      (font_first_free_tile),a
;
        ; Clear the font table
        ldy #sfont_handle_sizeof*.MAX_FONTS-1   ;        ld      hl,#font_table
                                                ;        ld      b,#sfont_handle_sizeof*.MAX_FONTS
1$:
        sta font_table,y            ;        ld      (hl+),a
        dey                         ;        dec     b
        bpl 1$                      ;        jr      nz,1$
        lda #3                      ;        ld      a,#3
        sta .fg_colour              ;        ld      (.fg_colour),a
        lda #0                      ;        xor     a
        sta .bg_colour              ;        ld      (.bg_colour),a
        jsr .cls_no_reset_pos       ;        call    .cls_no_reset_pos
                                    ;        pop     bc
        rts                         ;        ret

        
_cls::
.cls::  
;        XOR     A
;        LD      (.curx), A
;        LD      (.cury), A
.cls_no_reset_pos:
;        PUSH    DE
;        PUSH    HL
;        LD      HL,#0x9800
;        LD      E,#0x20         ; E = height
1$:
;        LD      D,#0x20         ; D = width
2$:
;        WAIT_STAT

;        LD      (HL),#.SPACE    ; Always clear
;        INC     HL
;        DEC     D
;        JR      NZ,2$
;        DEC     E
;        JR      NZ,1$
;        POP     HL
;        POP     DE
;        RET
        rts
        ; Support routines
_gotoxy::
;        lda     hl,2(sp)
;        ld      a,(hl+)
;        ld      (.curx),a
;        ld      a,(hl)
;        ld      (.cury),a
;        ret
        rts

_posx::
;        LD      A,(.mode)
;        AND     #.T_MODE
;        JR      NZ,1$
;        PUSH    BC
;        CALL    .tmode
;        POP     BC
1$:
;        LD      A,(.curx)
;        LD      E,A
;        RET
        rts

_posy::
;        LD      A,(.mode)
;        AND     #.T_MODE
;        JR      NZ,1$
;        PUSH    BC
;        CALL    .tmode
;        POP     BC
1$:
;        LD      A,(.cury)
;        LD      E,A
;        RET
        rts

        ;; Rewind the cursor
.rew_curs:
;        PUSH    HL
;        LD      HL,#.curx       ; X coordinate
;        XOR     A
;        CP      (HL)
;        JR      Z,1$
;        DEC     (HL)
;        JR      99$
1$:
;        LD      (HL),#.MAXCURSPOSX
;        LD      HL,#.cury       ; Y coordinate
;        XOR     A
;        CP      (HL)
;        JR      Z,99$
;        DEC     (HL)
99$:
;        POP     HL
;        RET
        rts

.cr_curs::
                                    ;        PUSH    HL
        lda #0                      ;        XOR     A
        sta .curx                   ;        LD      (.curx),A
                                    ;        LD      HL,#.cury       ; Y coordinate
        lda #.MAXCURSPOSY           ;        LD      A,#.MAXCURSPOSY
        cmp .cury                   ;        CP      (HL)
        beq 2$                      ;        JR      Z,2$
        inc .cury                   ;        INC     (HL)
        jmp 99$                     ;        JR      99$
2$:
        jsr .scroll                 ;        CALL    .scroll
99$:
                                    ;        POP     HL
        rts                         ;        RET


.adv_curs::
                                        ;        PUSH    HL
                                        ;        LD      HL,#.curx       ; X coordinate
        lda #.MAXCURSPOSX               ;        LD      A,#.MAXCURSPOSX
        cmp .curx                       ;        CP      (HL)
        beq 1$                          ;        JR      Z,1$
        inc .curx                       ;        INC     (HL)
        jmp 99$                         ;        JR      99$
1$:
        lda #0                          ;        LD      (HL),#0x00
        sta .curx
                                        ;        LD      HL,#.cury       ; Y coordinate
        lda #.MAXCURSPOSY               ;        LD      A,#.MAXCURSPOSY
        cmp .cury                       ;        CP      (HL)
        beq 2$                          ;        JR      Z,2$
        inc .cury                       ;        INC     (HL)
        jmp 99$                         ;        JR      99$
2$:
        ;; See if scrolling is disabled
        lda .mode                       ;        LD      A,(.mode)
        and #.M_NO_SCROLL               ;        AND     #.M_NO_SCROLL
        beq 3$                          ;        JR      Z,3$
        ;; Nope - reset the cursor to (0,0)
        lda #0                          ;        XOR     A
        sta .cury                       ;        LD      (.cury),A
        sta .curx                       ;        LD      (.curx),A
        jmp 99$                         ;        JR      99$
3$:     
        jsr .scroll                     ;        CALL    .scroll
99$:
                                        ;        POP     HL
        rts                             ;        RET


        ;; Scroll the whole screen
.scroll:
                                        ;        PUSH    BC
                                        ;        PUSH    DE
                                        ;        PUSH    HL
;        LD      HL,#0x9800
;        LD      BC,#0x9800+0x20 ; BC = next line
;        LD      E,#0x20-0x01    ; E = height - 1
1$:
;        LD      D,#0x20         ; D = width
2$:
;        WAIT_STAT
;        LD      A,(BC)
;        LD      (HL+),A
;        INC     BC

;        DEC     D
;        JR      NZ,2$
;        DEC     E
;        JR      NZ,1$

;        LD      D,#0x20
3$:
;        WAIT_STAT
;        LD      A,#.SPACE
;        LD      (HL+),A
;        DEC     D
;        JR      NZ,3$

                                        ;        POP     HL
                                        ;        POP     DE
                                        ;        POP     BC
        rts                             ;        RET


        ;; Enter text mode
.tmode::
;        DI                      ; Disable interrupts

        ;; Turn the screen off
;        LDH     A,(.LCDC)
;        AND     #LCDCF_ON
;        JR      Z,1$

        ;; Turn the screen off
;        CALL    .display_off

        ;; Remove any interrupts setup by the drawing routine
;        LD      BC,#.drawing_vbl
;        LD      HL,#.int_0x40
;        CALL    .remove_int
;        LD      BC,#.drawing_lcd
;        LD      HL,#.int_0x48
;        CALL    .remove_int
1$:

        jsr .tmode_out          ;        CALL    .tmode_out

        ;; Turn the screen on
;        LDH     A,(.LCDC)
;        OR      #(LCDCF_ON | LCDCF_BGON)
;        AND     #~(LCDCF_BG9C00 | LCDCF_BG8000)
;        LDH     (.LCDC),A

;        EI                      ; Enable interrupts

;        RET
        rts

        ;; Text mode (out only)
.tmode_out::
        ;; Clear screen
                            ;        CALL    .cls_no_reset_pos
        lda #.T_MODE        ;        LD      A,#.T_MODE
        sta *.mode          ;        LD      (.mode),A
        rts                 ;        RET

