/** @file nes/hardware.h
    Defines that let the NES hardware registers be accessed
    from C.
*/
#ifndef _HARDWARE_H
#define _HARDWARE_H

#include <types.h>

#define __BYTES extern UBYTE
#define __BYTE_REG extern volatile UBYTE

#define STATF_INT_VBL  0b10000000
#define STATF_9_SPR    0b01000000
#define STATF_SPR_COLL 0b00100000

#define VDP_REG_MASK   0b10000000
#define VDP_R0         0b10000000
extern UBYTE shadow_VDP_R0;

#define PPUCTRL     ((uint8_t*)0x2000);
#define PPUCTRL_SPR_8X8     0b00000000
#define PPUCTRL_SPR_8X16    0b00100010
extern UBYTE   shadow_PPUCTRL;

#define PPUMASK     ((uint8_t*)0x2001);
#define PPUMASK_NO_LCB_BG   0b00000010
#define PPUMASK_LCB_BG      0b00000000
#define PPUMASK_NO_LCB_SPR  0b00000100
#define PPUMASK_LCB_SPR     0b00000000
extern UBYTE   shadow_PPUMASK;

#define PPUSTATUS   ((uint8_t*)0x2002);
#define OAMADDR     ((uint8_t*)0x2003);
#define OAMDATA     ((uint8_t*)0x2004);
#define PPUSCROLL   ((uint8_t*)0x2005);
#define PPUADDR     ((uint8_t*)0x2006);
#define PPUDATA     ((uint8_t*)0x2007);
#define OAMDMA      ((uint8_t*)0x4014);

#define DEVICE_SCREEN_X_OFFSET 0
#define DEVICE_SCREEN_Y_OFFSET 0
#define DEVICE_SCREEN_WIDTH 32
#define DEVICE_SCREEN_HEIGHT 30
#define DEVICE_SCREEN_BUFFER_WIDTH 32
#define DEVICE_SCREEN_BUFFER_HEIGHT 30
#define DEVICE_SCREEN_MAP_ENTRY_SIZE 2
#define DEVICE_SPRITE_PX_OFFSET_X 0
#define DEVICE_SPRITE_PX_OFFSET_Y -1
#define DEVICE_SCREEN_PX_WIDTH (DEVICE_SCREEN_WIDTH * 8)
#define DEVICE_SCREEN_PX_HEIGHT (DEVICE_SCREEN_HEIGHT * 8)

#endif
