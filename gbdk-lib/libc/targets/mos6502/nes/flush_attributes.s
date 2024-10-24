    .include    "global.s"

    .area   _HOME

.ifne GBDK_NES_8X8_ATTRIBUTES
; 8x8 attributes implementation
_flush_shadow_attributes::
.flush_shadow_attributes::
    lda #0x0F
    sta *__vram_transfer_ppu_hi_mask
    ; Rows
    ; TL
    lda _attribute_row_dirty_planes+0
    beq 1$
    sta *_attribute_row_dirty
    lda #(CFG_CHR_A14)
    sta *__vram_transfer_mapper_bits
    ldy #(0x00)
    jsr _flush_shadow_attributes_rows
1$:
    ; TR
    lda _attribute_row_dirty_planes+1
    beq 2$
    sta *_attribute_row_dirty
    lda #(CFG_CHR_A14 | CFG_CHR_A12)
    sta *__vram_transfer_mapper_bits
    ldy #(0x40)
    jsr _flush_shadow_attributes_rows
2$:
    ; BL
    lda _attribute_row_dirty_planes+2
    beq 3$
    sta *_attribute_row_dirty
    lda #(CFG_CHR_A14 | CFG_CHR_A13)
    sta *__vram_transfer_mapper_bits
    ldy #(0x00+0x80)
    jsr _flush_shadow_attributes_rows
3$:
    ; BR
    lda _attribute_row_dirty_planes+3
    beq 4$
    sta *_attribute_row_dirty
    lda #(CFG_CHR_A14 | CFG_CHR_A12 | CFG_CHR_A13)
    sta *__vram_transfer_mapper_bits
    ldy #(0x40+0x80)
    jsr _flush_shadow_attributes_rows
4$:
    ; Columns
    ; TL
    lda _attribute_column_dirty_planes+0
    beq 5$
    sta *_attribute_column_dirty
    lda #CFG_CHR_A14
    sta *__vram_transfer_mapper_bits
    ldy #(0x00)
    jsr _flush_shadow_attributes_columns
5$:
    ; TR
    lda _attribute_column_dirty_planes+1
    beq 6$
    sta *_attribute_column_dirty
    lda #(CFG_CHR_A14 | CFG_CHR_A12)
    sta *__vram_transfer_mapper_bits
    ldy #(0x40)
    jsr _flush_shadow_attributes_columns
6$:
    ; BL
    lda _attribute_column_dirty_planes+2
    beq 7$
    sta *_attribute_column_dirty
    lda #(CFG_CHR_A14 | CFG_CHR_A13)
    sta *__vram_transfer_mapper_bits
    ldy #(0x00+0x80)
    jsr _flush_shadow_attributes_columns
7$:
    ; BR
    lda _attribute_column_dirty_planes+3
    beq 8$
    sta *_attribute_column_dirty
    lda #(CFG_CHR_A14 | CFG_CHR_A12 | CFG_CHR_A13)
    sta *__vram_transfer_mapper_bits
    ldy #(0x40+0x80)
    jsr _flush_shadow_attributes_columns
8$:
    lda #0x00
    sta *__vram_transfer_mapper_bits
    sta _attribute_row_dirty_planes+0
    sta _attribute_row_dirty_planes+1
    sta _attribute_row_dirty_planes+2
    sta _attribute_row_dirty_planes+3
    sta _attribute_column_dirty_planes+0
    sta _attribute_column_dirty_planes+1
    sta _attribute_column_dirty_planes+2
    sta _attribute_column_dirty_planes+3
    lda #0x20
    sta *__vram_transfer_ppu_hi_mask
    rts
.else
; Regular 16x16 attributes implementation
_flush_shadow_attributes::
.flush_shadow_attributes::
    lda #0x23
    sta *__vram_transfer_ppu_hi_mask
    ldy #0
    jsr _flush_shadow_attributes_rows
    ldy #0
    jsr _flush_shadow_attributes_columns
    lda #0x20
    sta *__vram_transfer_ppu_hi_mask
    rts
.endif


;
; Writes every row of attributes from _shadow_attributes that's been marked
; as dirty in the _attribute_row_dirty byte to PPU memory.
;
_flush_shadow_attributes_rows:
    lda #<PPU_AT0
    sta *.tmp
    lda *__vram_transfer_ppu_hi_mask
    sta *.tmp+1
_flush_shadow_attributes_row_loop:
    lsr *_attribute_row_dirty
    bcc 1$
    jmp _flush_shadow_attributes_update_row
1$:
    beq _flush_shadow_attributes_end
_flush_shadow_attributes_next_row:
    ; Y += 8
    tya
    clc
    adc #8
    tay
    ; .tmp += 8
    lda *.tmp
    adc #8
    sta *.tmp
    jmp _flush_shadow_attributes_row_loop
_flush_shadow_attributes_end:
    rts

;
; Flushes all dirty rows of _attribute_shadow by writing them to PPU memory
;
_flush_shadow_attributes_update_row:
    ; Update all 8 bytes of row for now, as each row in _attribute_row_dirty only stores 1 bit
    ; TODO: Could store 8 bytes and update range, at expense of 7 more bytes.
    lda *.tmp+1
    tax
    lda *.tmp
    jsr .ppu_stripe_begin_horizontal
    ; Write 8 bytes
    i = 0
    .rept 8
    lda _attribute_shadow+i,y
    jsr .ppu_stripe_write_byte
    i = i + 1
    .endm
    jsr .ppu_stripe_end
    jmp _flush_shadow_attributes_next_row

;
; Writes every column of attributes from _shadow_attributes that's been marked
; as dirty in the _attribute_column_dirty byte to PPU memory.
;
;
_flush_shadow_attributes_columns:
    lda #<PPU_AT0
    sta *.tmp
    lda *__vram_transfer_ppu_hi_mask
    sta *.tmp+1
_flush_shadow_attributes_columns_loop:
    lsr *_attribute_column_dirty
    bcc 1$
    jmp _flush_shadow_attributes_update_column
1$:
    beq _flush_shadow_attributes_columns_end
_flush_shadow_attributes_columns_next_column:
    ; Y += 1
    iny
    ; .tmp += 1
    inc *.tmp
    jmp _flush_shadow_attributes_columns_loop
_flush_shadow_attributes_columns_end:
    rts

.macro WRITEVERT
    lda *.tmp+1
    tax
    lda *.tmp
    clc
    adc #(8*i)
    jsr .ppu_stripe_begin_vertical
    lda _attribute_shadow+8*i,y
    jsr .ppu_stripe_write_byte
    lda _attribute_shadow+8*i+32,y
    jsr .ppu_stripe_write_byte
    jsr .ppu_stripe_end
.endm

;
; Flushes all dirty rows of _attribute_shadow by writing them to PPU memory
;
_flush_shadow_attributes_update_column:
    ; Update all 8 bytes of column for now, as each column in _attribute_column_dirty only stores 1 bit
    ; As PPU has no increment-by-8 feature, split writes into 4 separate stripes 2 bytes each
    ; TODO: Could make a dedicated unrolled transfer routine in nmi handler that writes all 8 bytes as one stripe.
    i = 0
    .rept 4
    WRITEVERT
    i = i + 1
    .endm
    jmp _flush_shadow_attributes_columns_next_column
