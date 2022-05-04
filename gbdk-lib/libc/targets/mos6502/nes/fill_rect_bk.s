	.include	"global.s"

	.area	OSEG (PAG, OVR)
	_fill_bkg_rect_PARM_3::     .ds 1
	_fill_bkg_rect_PARM_4::     .ds 1
	_fill_bkg_rect_PARM_5::     .ds 1

	.area	_HOME

_fill_bkg_rect::
	; TODO
	rts
