	.include	"global.s"

	.area _HOME

___sdcc_bcall_ehl::			; Performs a long call.
	ldh	a, (__current_bank)
	push	af			; Push the current bank onto the stack
	ld	a, e
	ldh	(__current_bank), a
	ld	(.MBC_ROM_PAGE), a	; Perform the switch
	rst	0x20
	pop	bc			; Pop the old bank
	ld	c, a
	ld	a, b
	ldh	(__current_bank), a
	ld	(.MBC_ROM_PAGE), a
	ld	a, c
	ret