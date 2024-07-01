/*
    zapper.c

    An example demonstrating reading the NES Zapper light gun. 
    
    Provides tracking of Y-position, and (extremely noisy) tracking of X-position.
    
    It is vital to note that this needs running on real hardware. 
    
    Emulators give a false impression of a decent result for the X-tracking.
    In reality X-tracking is nearly useless with a real Zapper. At best
    some additional filtering of X-input *might* allow determining roughly what 
    side of the screen the gun points at, to distinguish two horizontally-aligned
    targets.
    
    TODO: Add typical blanking of BG / flashing of screen when trigger is pulled, and
    detection based on this.
*/

#include <stdio.h>
#include <gbdk/platform.h>
#include <gbdk/font.h>
#include <gbdk/console.h>

#define CURSOR_SPRI 0
#define CURSOR_TILE 0

// XXXXXXXX
// XX......
// XX......
// XX......
// XX......
// XX......
// XX......
// XX......
uint8_t sprite_data[] = {
    0xFF,0xFF,0xC0,0xC0,0xC0,0xC0,0xC0,0xC0,
    0xFF,0xFF,0xC0,0xC0,0xC0,0xC0,0xC0,0xC0,
};

const uint8_t pattern[] = {
    0xFF,0x81,0x81,0x81,0x81,0x81,0x81,0xFF,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
};

//
//
uint16_t get_zapper_position_ntsc() NONBANKED NAKED;
uint16_t get_zapper_position_ntsc() NONBANKED NAKED {
//    i; l; ptr; bank;
__asm
    .define .acc "REGTEMP+1"

    ldy #1
    ldx #16 ; Delay value - may need adjusting if crt0 changes
    jmp 0$

.bndry 0x100
    nop
    nop
    nop
    nop
0$:
    dex
    bne 0$
    nop
    nop
    nop
1$:
    lda #0x08
    ldx #8
    ; 11 CPU cycles = 33 NTSC pixels
2$:
    bit 0x4017
    beq 4$
    dex
    bne 2$      ; -> 88 + 2 = 90 NTSC cycles

    ; Light not detected - continue with scan line loop
    
    ; Add fractional cycles and branch on carry
    lda #171 ; NTSC fractional cycle count
    clc
    adc *.acc
    sta *.acc
    bcs 30$
30$:
    sta *.acc   ; -> 15.666 NTSC cycles
    
    iny
    cpy #160 ;*.viewport_height
    bne 1$      ; -> 11 NTSC cycles
    ; Return out-of-bounds result
    ldx #0xFF
    txa
    rts

4$:
    ; Light detected - exit loop and return result
    
    ; figure out X position = (8 - X) * 33 = ((8 - X) << 5) + (8 - X)
    txa
    eor #0xFF
    clc
    adc #1
    clc
    adc #8
    sta *REGTEMP
    asl
    asl
    asl
    asl
    asl
    clc
    adc *REGTEMP
    bcc 5$
    lda #256-32
5$:
    iny
    sty *REGTEMP+1
    ldx *REGTEMP+1
    rts
__endasm;
}

//
//
uint16_t get_zapper_position_pal() NONBANKED NAKED;
uint16_t get_zapper_position_pal() NONBANKED NAKED {
__asm
    ldy #1
    ldx #16 ; Delay value - may need adjusting if crt0 changes
    jmp 0$

.bndry 0x100
    nop
    nop
    nop
    nop
0$:
    dex
    bne 0$
    nop
1$:
    lda #0x08
    ; 11 CPU cycles = 33 NTSC pixels

    ;
    bit 0x4017
    beq 20$
    nop
    nop
    ;
    bit 0x4017
    beq 21$
    nop
    nop
    ;
    bit 0x4017
    beq 22$
    nop
    nop
    ;
    bit 0x4017
    beq 23$
    nop
    nop
    ;
    bit 0x4017
    beq 24$
    nop
    nop
    ;
    bit 0x4017
    beq 25$
    nop
    nop
    ;
    bit 0x4017
    beq 26$
    nop
    nop
    ;
    bit 0x4017
    beq 27$
    nop
    nop

    ; Light not detected - continue with scanline loop
    
    ; Add fractional cycles and branch on carry
    lda #144 ; PAL fractional cycle count
    clc
    adc *.acc
    sta *.acc
    bcs 30$
30$:
    sta *.acc   ; -> 15.5625 PAL cycles
    nop
    iny
    cpy #160 ;*.viewport_height
    bne 1$      ; -> 11 cycles
    ; Return out-of-bounds result
    ldx #0xFF
    txa
    rts
20$:
    ldx #0
    beq 4$
21$:
    ldx #1
    bne 4$
22$:
    ldx #2
    bne 4$
23$:
    ldx #3
    bne 4$
24$:
    ldx #4
    bne 4$
25$:
    ldx #5
    bne 4$
26$:
    ldx #6
    bne 4$
27$:
    ldx #7
    bne 4$
4$:
    ; Light detected - exit loop and return result
    txa
    asl
    asl
    asl
    asl
    asl
    iny
    sty *REGTEMP+1
    ldx *REGTEMP+1
    rts
__endasm;
}


uint16_t vsync_and_zapper_position()
{
    vsync();
    return (get_system() == SYSTEM_50HZ) ? get_zapper_position_pal() : get_zapper_position_ntsc();
}

/*

 Dummy LCD ISR - just to make sure vblank handler runs in constant time.

 */
void dummy_lcd_isr(void)
{
}

void main(void)
{
    font_t ibm_font;
    int i;
    // Init font system and load font
    font_init();
    ibm_font = font_load(font_ibm);
    
    // Fill the screen background with a single tile pattern
    fill_bkg_rect(0, 0, DEVICE_SCREEN_WIDTH, 20, 0xF0);

    // Set tile data for background
    set_bkg_native_data(0xF0, 1, pattern);
    
    SPRITES_8x8;
    
    CRITICAL {
        add_LCD(dummy_lcd_isr);
    }
    // load sprite tile data into VRAM
    set_sprite_native_data(0, 1, sprite_data);
    while(TRUE)
    {
        //
        uint16_t xy_pos = vsync_and_zapper_position();
        uint8_t x_pos = (xy_pos & 0xFF) - 16;
        uint8_t y_pos = (xy_pos >> 8) - 16;
        // Quantized positions (divided by 32)
        uint8_t x_posq = x_pos >> 5;
        uint8_t y_posq = y_pos >> 5;
        if(x_pos != 0xFF && y_pos != 0xFF) // Only draw cursor if in-range
        {
            // Draw rectangle to indicate zapper screen position
            move_sprite(CURSOR_SPRI, x_pos, y_pos);
            set_sprite_tile(CURSOR_SPRI, CURSOR_TILE);
            set_sprite_prop(CURSOR_SPRI, 0);
            //
            move_sprite(CURSOR_SPRI + 1, x_pos + 24, y_pos);
            set_sprite_tile(CURSOR_SPRI + 1, CURSOR_TILE);
            set_sprite_prop(CURSOR_SPRI + 1, S_FLIPX);
            //
            move_sprite(CURSOR_SPRI + 2, x_pos, y_pos + 24);
            set_sprite_tile(CURSOR_SPRI + 2, CURSOR_TILE);
            set_sprite_prop(CURSOR_SPRI + 2, S_FLIPY);
            //
            move_sprite(CURSOR_SPRI + 3, x_pos + 24, y_pos + 24);
            set_sprite_tile(CURSOR_SPRI + 3, CURSOR_TILE);
            set_sprite_prop(CURSOR_SPRI + 3, S_FLIPX | S_FLIPY);
        }
        else
        {
            hide_sprite(0);
            hide_sprite(1);
            hide_sprite(2);
            hide_sprite(3);
        }
    }
}
