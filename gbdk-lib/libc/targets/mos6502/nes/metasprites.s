    .include    "global.s"

    .title  "Metasprites"
    .module Metasprites

    .area	GBDKOVR (PAG, OVR)
    ___move_metasprite_PARM_2:: .ds 2
    ___move_metasprite_PARM_3:: .ds 2
    ___current_metasprite::     .ds 2
    ___current_base_tile::      .ds 1
    ___current_base_prop::      .ds 1

    .area   _HOME

.define xPos  "___move_metasprite_PARM_2"
.define yPos  "___move_metasprite_PARM_3"

.define id    ".tmp+1"

; uint8_t __move_metasprite(uint8_t id, int16_t x, int16_t y)

___move_metasprite::
    sta *id ;jsr .move_metasprite_prologue
    asl
    asl
    tax
    ldy #0
___move_metasprite_loop:
    lda [*___current_metasprite],y      ; dy
    bmi ___move_metasprite_dyNeg
    clc
    adc *yPos
    sta *yPos
    bcc 1$
    inc *yPos+1
    ;bne ___move_metasprite_outsideY
1$:
___move_metasprite_loop_writePosY:
    sta _shadow_OAM+OAM_POS_Y,x
    lda *yPos+1
    bne ___move_metasprite_outsideY
    iny
    lda [*___current_metasprite],y      ; dx
    bmi ___move_metasprite_dxNeg
    clc
    adc *xPos
    sta *xPos
    bcc 2$
    inc *xPos+1
    ;bne ___move_metasprite_outsideX
2$:
___move_metasprite_loop_writePosX:
    sta _shadow_OAM+OAM_POS_X,x
    lda *xPos+1
    bne ___move_metasprite_outsideX
    iny
    lda [*___current_metasprite],y      ; tile index
    iny
    clc
    adc *___current_base_tile
    sta _shadow_OAM+OAM_TILE_INDEX,x
    lda [*___current_metasprite],y      ; props
;;; HACK: gbstudio does not use _current_base_prop    
    ;adc *___current_base_prop
;;;
    iny
    sta _shadow_OAM+OAM_ATTRIBUTES,x
    ;inx
    ;inx
    ;inx
    ;inx
    txa
    .db 0xCB, 0xFC  ; AXS #0xFC
    bne ___move_metasprite_loop
___move_metasprite_end:
    ;jmp .move_metasprite_epilogue
    ; Return number of hardware sprites used
    txa
    lsr
    lsr
    sec
    sbc *id
    rts

___move_metasprite_dxNeg:
    clc
    adc *xPos
    sta *xPos
    bcs 1$
    dec *xPos+1
1$:
    jmp ___move_metasprite_loop_writePosX

___move_metasprite_dyNeg:
    cmp #0x80
    beq ___move_metasprite_end
    clc
    adc *yPos
    sta *yPos
    bcs 1$
    dec *yPos+1
1$:
    jmp ___move_metasprite_loop_writePosY

___move_metasprite_outsideY:
    iny
    lda [*___current_metasprite],y      ; dx
    bmi ___move_metasprite_outsideY_dxNeg
    clc
    adc *xPos
    sta *xPos
    bcc 1$
    inc *xPos+1
1$:
___move_metasprite_outsideX:
    iny
    ; Skip tile index / props
    iny
    iny
    lda #0xF0
    sta _shadow_OAM+OAM_POS_Y,x
    jmp ___move_metasprite_loop

___move_metasprite_outsideY_dxNeg:
    clc
    adc *xPos
    sta *xPos
    bcs 1$
    dec *xPos+1
1$:
    jmp ___move_metasprite_outsideX
