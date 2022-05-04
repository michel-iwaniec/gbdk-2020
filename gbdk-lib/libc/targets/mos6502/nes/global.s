        .NEAR_CALLS = 1         ; <near_calls> - tag so that sed can change this

        _VRAM           = 0x8000 ; $8000->$9FFF
        _VRAM8000       = 0x8000
        _VRAM8800       = 0x8800
        _VRAM9000       = 0x9000
        _SCRN0          = 0x9800 ; $9800->$9BFF
        _SCRN1          = 0x9C00 ; $9C00->$9FFF
        _SRAM           = 0xA000 ; $A000->$BFFF
        _RAM            = 0xC000 ; $C000->$CFFF / $C000->$DFFF
        _RAMBANK        = 0xD000 ; $D000->$DFFF
        _OAMRAM         = 0xFE00 ; $FE00->$FE9F
        _IO             = 0xFF00 ; $FF00->$FF7F,$FFFF
        _AUD3WAVERAM    = 0xFF30 ; $FF30->$FF3F
        _HRAM           = 0xFF80 ; $FF80->$FFFE

        ;; MBC Equates

        .MBC1_ROM_PAGE  = 0x2000 ; Address to write to for MBC1 switching
        .MBC_ROM_PAGE   = 0x2000 ; Default platform MBC rom switching address

        rRAMG           = 0x0000 ; $0000->$1fff
        rROMB0          = 0x2000 ; $2000->$2fff
        rROMB1          = 0x3000 ; $3000->$3fff - If more than 256 ROM banks are present.
        rRAMB           = 0x4000 ; $4000->$5fff - Bit 3 enables rumble (if present)

        ;;  Keypad
        .UP             = 0x10
        .DOWN           = 0x20
        .LEFT           = 0x40
        .RIGHT          = 0x80
        .A              = 0x01
        .B              = 0x02
        .SELECT         = 0x04
        .START          = 0x08

        ;;  Screen dimensions
        .MAXCURSPOSX    = 0x1F  ; In tiles
        .MAXCURSPOSY    = 0x1D

        .SCREENWIDTH    = 0x100
        .SCREENHEIGHT   = 0xF0
        .MINWNDPOSX     = 0x07
        .MINWNDPOSY     = 0x00
        .MAXWNDPOSX     = 0x00
        .MAXWNDPOSY     = 0x00

        ;; Hardware registers

        .SCY            = 0x2005  ; Scroll Y
        rSCY            = 0x2005

        .SCX            = 0x2005  ; Scroll X
        rSCX            = 0x2005

        rLYC            = 0xFF45

        .DMA            = 0x4014  ; DMA transfer
        rDMA            = 0x4014

        ;; OAM related constants

        OAM_COUNT       = 64  ; number of OAM entries in OAM RAM

        OAMF_PRI        = 0b00100000 ; Priority
        OAMF_YFLIP      = 0b10000000 ; Y flip
        OAMF_XFLIP      = 0b01000000 ; X flip

        OAMF_PALMASK    = 0b00000011 ; Palette (GBC)

        OAMB_PRI        = 5 ; Priority
        OAMB_YFLIP      = 7 ; Y flip
        OAMB_XFLIP      = 6 ; X flip

        ;; GBDK library screen modes

        .G_MODE         = 0x01  ; Graphic mode
        .T_MODE         = 0x02  ; Text mode (bit 2)
        .T_MODE_OUT     = 0x02  ; Text mode output only
        .T_MODE_INOUT   = 0x03  ; Text mode with input
        .M_NO_SCROLL    = 0x04  ; Disables scrolling of the screen in text mode
        .M_NO_INTERP    = 0x08  ; Disables special character interpretation

        ;; Table of routines for modes
        .MODE_TABLE     = 0xFFE0

        ;; C related
        ;; Overheap of a banked call.  Used for parameters
        ;;  = ret + real ret + bank

        .if .NEAR_CALLS
        .BANKOV         = 2

        .else
        .BANKOV         = 6

        .endif

        .globl  __current_bank
        .globl  __shadow_OAM_base

        ;; Global variables
        .globl  .mode
        .globl  .tmp

        .globl _shadow_PPUCTRL, _shadow_PPUMASK
        
        ;; Identity table for register-to-register-adds and bankswitching
        .globl .identity, _identity

        ;; Global routines

        ;.globl  .reset

        .globl  .display_off, .display_on

        .globl  .wait_vbl_done
        
        .globl  .writeNametableByte

        ;; Interrupt routines
        ;.globl  .add_VBL

        ;; Symbols defined at link time
        ;.globl  .STACK
        .globl  _shadow_OAM
        ;.globl  .refresh_OAM

        ;; Main user routine
        .globl  _main

        ;; Macro definitions
