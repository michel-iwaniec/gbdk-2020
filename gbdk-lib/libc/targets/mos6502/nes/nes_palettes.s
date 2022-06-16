    .include    "global.s"

    .area   OSEG (PAG, OVR)
    _set_bkg_palette_PARM_3::   .ds 2
    .nb_palettes:               .ds 1

    .area   _HOME

; void set_bkg_palette(uint8_t first_palette, uint8_t nb_palettes, palette_color_t *rgb_data) OLDCALL;
_set_bkg_palette::
    .define .src "_set_bkg_palette_PARM_3"
    txa
    asl
    asl
    sta *.nb_palettes
    ldy #0
    ldx #1
    lda [*.src],y
    iny
    sta *__crt0_paletteShadow
2$:
    ; skip mirror entries
    tya
    and #0x03
    beq 1$
    lda [*.src],y
    sta *__crt0_paletteShadow,x
    inx
1$:
    iny
    cpy *.nb_palettes
    bne 2$
    rts
