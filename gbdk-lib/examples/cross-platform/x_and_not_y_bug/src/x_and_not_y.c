/*
 Demonstrates a bug with SDCC codegen (r14635) that
 causes expression (x & ~y) to always evaluate to
 zero when not stored to an intermediate variable.
*/

#include <stdio.h>
#include <gbdk/platform.h>
#include <gbdk/font.h>
#include <gbdk/console.h>

uint8_t x = 0xFF;
uint8_t y = 0xAA;

//
// Failing macro: (x & ~y) is always zero
//
#define XANDNOTY_MACRO() (x & ~y)

//
// Working function: "x & ~y" has expected value (0x55)
//
uint8_t xandnoty_function()
{
    return (x & ~y);
}

//
// Print byte value as hex
//
void print_hex(uint8_t v)
{
    printf(" 0x%X", (int)v);
}

void main(void)
{
    uint8_t r = 0;
    font_t ibm_font;
    // Init font system and load font
    font_init();
    ibm_font = font_load(font_ibm);
    DISPLAY_ON;
    gotoxy(1, 1);
    printf("Demonstrates compiler");
    gotoxy(1, 2);
    printf("bug for \"x & ~y\"");
    gotoxy(1, 4);
    printf("working function call");
    gotoxy(1, 5);
    //r = ;
    //printf(" 0x%X", r);
    print_hex(xandnoty_function());
    // Working macro (temporarily stores expression to r)
    gotoxy(1, 7);
    printf("WORKING MACRO (temp):");
    gotoxy(1, 8);
    r = XANDNOTY_MACRO();
    print_hex(r);
    // Working macro (no temporary storage, but still uses print_hex)
    gotoxy(1, 10);
    printf("WORKING MACRO (notemp):");
    gotoxy(1, 11);    
    print_hex(XANDNOTY_MACRO());
    // Failing macro (no temporary storage, pass directly to printf)
    gotoxy(1, 13);
    printf("FAILING MACRO (direct printf):");
    gotoxy(1, 14);    
    printf(" 0x%X", (int)XANDNOTY_MACRO());
    vsync();
}
