#include <stdint.h>
#include "bcd.h"

void uint2bcd(unsigned int i, BCD * value) __naked
{
    i; value; // suppress warninig: unreferenced function argument
__asm
            lda     HL, 2(SP)
            ld      A, (HL+)        ; DE: uint
            ld      E, A
            ld      A, (HL+)
            ld      D, A
            ld      A, (HL+)
            ld      H, (HL)
            ld      L, A            ; HL: dest

            push    BC

            ; clear value
            xor     A
            ld      BC, #-4
            
            ld      (HL+), A
            ld      (HL+), A
            ld      (HL+), A
            ld      (HL+), A
            add     HL, BC

            ld      B, #16
1$:            
            sla     E
            rl      D
            
            ld      A, (HL)
            adc     A
            daa
            ld      (HL+), A
            ld      A, (HL)
            adc     A
            daa
            ld      (HL+), A
            ld      A, (HL)
            adc     A
            daa
            ld      (HL-), A
            
            dec     HL
            
            dec     B
            jr      NZ, 1$

            pop     BC
            ret
__endasm;
}

void bcd_add(BCD * sour, BCD * value) __naked
{
    sour; value; // suppress warninig: unreferenced function argument
__asm
            lda     HL, 5(SP)
            ld      D, (HL)         
            dec     HL
            ld      E, (HL)         ; DE: value
            dec     HL
            ld      A, (HL-)
            ld      L, (HL)
            ld      H, A            ; HL: sour

            or      A               ; clear C, HC

            ld      A,(DE)
            add     (HL)
            daa
            ld      (HL+), A
            inc     DE
            
            ld      A,(DE)
            adc     (HL)
            daa
            ld      (HL+), A
            inc     DE
            
            ld      A,(DE)
            adc     (HL)
            daa
            ld      (HL+), A
            inc     DE
            
            ld      A,(DE)
            adc     (HL)
            daa
            ld      (HL+), A
            
            ret
__endasm;
}

void bcd_sub(BCD * sour, BCD * value) __naked
{
    sour; value; // suppress warninig: unreferenced function argument 
__asm
            lda     HL, 2(SP)
            ld      E, (HL)         
            inc     HL
            ld      D, (HL)         ; DE: sour
            inc     HL
            ld      A, (HL+)
            ld      H, (HL)
            ld      L, A            ; HL: value

            or      A               ; clear C, HC

            ld      A,(DE)
            sub     (HL)
            daa
            ld      (DE), A
            inc     DE
            inc     HL
            
            ld      A,(DE)
            sbc     (HL)
            daa
            ld      (DE), A
            inc     DE
            inc     HL
            
            ld      A,(DE)
            sbc     (HL)
            daa
            ld      (DE), A
            inc     DE
            inc     HL
            
            ld      A,(DE)
            sbc     (HL)
            daa
            ld      (DE), A
            
            ret
__endasm;
}

uint8_t bcd2text(BCD * bcd, uint8_t tile_offset, unsigned char * buffer) __naked
{
    bcd; tile_offset; buffer;
__asm
            push    BC
            
            lda     HL, 4(SP)
            ld      E, (HL)         
            inc     HL
            ld      D, (HL)         ; DE: bcd
            inc     HL
            ld      C, (HL)         ; C: digit offset
            inc     HL
            ld      A, (HL+)
            ld      H, (HL)
            ld      L, A            ; HL: buffer

            inc     DE
            inc     DE
            inc     DE

            ld      B, #0x0f

            ld      A, (DE)
            swap    A
            and     B
            add     C
            ld      (HL+), A
            ld      A, (DE)
            and     B
            add     C
            ld      (HL+), A
            dec     DE
            
            ld      A, (DE)
            swap    A
            and     B
            add     C
            ld      (HL+), A
            ld      A, (DE)
            and     B
            add     C
            ld      (HL+), A
            dec     DE

            ld      A, (DE)
            swap    A
            and     B
            add     C
            ld      (HL+), A
            ld      A, (DE)
            and     B
            add     C
            ld      (HL+), A
            dec     DE
            
            ld      A, (DE)
            swap    A
            and     B
            add     C
            ld      (HL+), A
            ld      A, (DE)
            and     B
            add     C
            ld      (HL+), A
            dec     DE
            
            xor     A
            ld      (HL+), A
            
            ld      D, A
            ld      E, #0x08
            
            pop     BC
            ret
__endasm;
}
