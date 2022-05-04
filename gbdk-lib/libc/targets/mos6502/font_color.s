	.include        "global.s"

	.globl .fg_colour, .bg_colour

	.area _HOME
_font_color::
                                ;	LDA	HL,2(SP)	; Skip return address and registers
                                ;	LD	A,(HL+)	        ; A = Foreground
    sta .fg_colour              ;	LD	(.fg_colour),a
                                ;	LD	A,(HL)
    stx .bg_colour              ;	LD	(.bg_colour),a
    rts                         ;	RET
