    .include    "global.s"

    .title  "Metasprites"
    .module Metasprites

    .area	OSEG (PAG, OVR)
    ___current_metasprite::     .ds 2
    ___current_base_tile::      .ds 1
    ___move_metasprite_PARM_3:: .ds 2

    .area   _INITIALIZED
    ___render_shadow_OAM:: .ds     0x01

    .area   _INITIALIZER
    .db     #>_shadow_OAM

    .area   _HOME

; uint8_t __move_metasprite(uint8_t id, uint8_t x, uint8_t y)
.define xPos  ".tmp"
.define yPos  "___move_metasprite_PARM_3"
___move_metasprite::
    stx xPos
    asl
    asl
    tax
    lda *_shadow_PPUCTRL
    lsr
    lsr
    lsr
    lsr
    lsr
    and #1
    ora *___current_base_tile
    sta *___current_base_tile
    ldy #0
___move_metasprite_loop:
    lda [*___current_metasprite],y      ; dy
    iny
    cmp #0x80
    beq ___move_metasprite_end
    clc
    adc *yPos
    sta *yPos
    sta _shadow_OAM+0,x
    lda [*___current_metasprite],y      ; dx
    iny
    clc
    adc *xPos
    sta *xPos
    sta _shadow_OAM+3,x
    lda [*___current_metasprite],y      ; tile index
    iny
    clc
    adc *___current_base_tile
    sta _shadow_OAM+1,x
    lda [*___current_metasprite],y      ; props
    iny
    sta _shadow_OAM+2,x
    inx
    inx
    inx
    inx
    bne ___move_metasprite_loop
___move_metasprite_end:
    txa
    lsr
    lsr
    rts
