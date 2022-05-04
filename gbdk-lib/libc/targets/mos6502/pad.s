	.include	"global.s"

	.area	_HOME

_read_joypad::
	lda #1
	sta 0x4016
	lda #0
	sta 0x4016
	ldy #8
_read_joypad_loop:
	lda 0x4016,x
	lsr
	ror *.tmp+1
	dey
	bne _read_joypad_loop
	lda *.tmp+1
	rts

	;; Wait until all buttons have been released
.padup::
_waitpadup::
	jsr .jpad
	beq _waitpadup
	rts

	;; Get Keypad Button Status
	;; The following bits are set if pressed:
	;;   0x80 - Start   0x08 - Down
	;;   0x40 - Select  0x04 - Up
	;;   0x20 - B	    0x02 - Left
	;;   0x10 - A	    0x01 - Right
_joypad::
.jpad::
	ldx #0
	jmp _read_joypad

	;; Wait for the key to be pressed
_waitpad::
.wait_pad::
	sta *.tmp
.wait_pad_loop:
	jsr .jpad
	and *.tmp
	beq .wait_pad_loop
	rts
