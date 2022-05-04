        .include        "global.s"

        .globl __current_1bpp_colors

        .area	OSEG (PAG, OVR)
        src:                        .ds 2
        firstTile:                  .ds 1
        numTiles:                   .ds 1
        _set_bkg_1bpp_data_PARM_3:: .ds 2
        fg_p0:                      .ds 1
        fg_p1:                      .ds 1
        bg_p0:                      .ds 1
        bg_p1:                      .ds 1
        p0:                         .ds 1
        p1:                         .ds 1

        .area   _HOME

_set_bkg_1bpp_data::
        sta *firstTile
        stx *numTiles
        ;
        sta *src
        lda #0
        asl *src
        rol
        asl *src
        rol
        asl *src
        rol
        asl *src
        rol
        sta *src+1
        

        lda *_shadow_PPUCTRL
        and #0x10
        ora *src+1
        sta 0x2006
        lda *src
        sta 0x2006

        lda *_set_bkg_1bpp_data_PARM_3
        sta *src
        lda *_set_bkg_1bpp_data_PARM_3+1
        sta *src+1

_set_bkg_1bpp_data_tile_loop:
        ldy #0
_set_bkg_1bpp_data_tile_loop_p0:
        ldx .fg_colour
        lda replicate_bits_p0,x
        sta fg_p0
        ldx .bg_colour
        lda replicate_bits_p0,x
        sta bg_p0
        lda [*src],y
        ldx #8
_set_bkg_1bpp_data_bit_loop_p0:
        asl
        bcs _set_bkg_1bpp_data_fg_p0
        asl bg_p0
        rol p0
        jmp _set_bkg_1bpp_data_bit_loop_p0_skip
_set_bkg_1bpp_data_fg_p0:
        asl fg_p0
        rol p0
_set_bkg_1bpp_data_bit_loop_p0_skip:
        dex
        bne _set_bkg_1bpp_data_bit_loop_p0
        lda p0
        sta 0x2007 ;PPUDATA ;sta [*dst],y
        iny
        cpy #8
        bne _set_bkg_1bpp_data_tile_loop_p0

        ldy #0
_set_bkg_1bpp_data_tile_loop_p1:
        ldx .fg_colour
        lda replicate_bits_p1,x
        sta fg_p1
        ldx .bg_colour
        lda replicate_bits_p1,x
        sta bg_p1
        lda [*src],y
        ldx #8
_set_bkg_1bpp_data_bit_loop_p1:
        asl
        bcs _set_bkg_1bpp_data_fg_p1
        asl bg_p1
        rol p1
        jmp _set_bkg_1bpp_data_bit_loop_p1_skip
_set_bkg_1bpp_data_fg_p1:
        asl fg_p1
        rol p1
_set_bkg_1bpp_data_bit_loop_p1_skip:
        dex
        bne _set_bkg_1bpp_data_bit_loop_p1
        lda p1
        sta 0x2007 ;PPUDATA ;sta [*dst],y
        iny
        cpy #8
        bne _set_bkg_1bpp_data_tile_loop_p1
        ; src += 8
        lda *src
        clc
        adc #8
        sta *src
        lda *src+1
        adc #0
        sta *src+1
        dec *numTiles
        beq 10$
        jmp _set_bkg_1bpp_data_tile_loop
10$:
        rts

replicate_bits_p0:
    .db 0x00            ; 00
    .db 0xFF            ; 01
    .db 0x00            ; 10
    .db 0xFF            ; 11

replicate_bits_p1:
    .db 0x00            ; 00
    .db 0x00            ; 01
    .db 0xFF            ; 10
    .db 0xFF            ; 11
