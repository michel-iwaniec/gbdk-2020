	.include	"global.s"

	.title	"screen modes"
	.module	Modes

    .area	OSEG (PAG, OVR)
    temp_word:                  .ds 2

	;; BANKED:	checked
	.area	_HOME

_mode::
	;LDA	HL,2(SP)	; Skip return address
	;LD	L,(HL)
	;LD	H,#0x00

.set_mode::
	;LD	A,L
	sta .mode                       ; LD	(.mode),A

    ;; AND to get rid of the extra flags
    and #0x03                       ; AND	#0x03
                                    ; LD	L,A
                                    ; LD	BC,#.MODE_TABLE
    asl                             ; SLA	L		; Multiply mode by 4
    asl                             ; SLA	L
    clc                             ; ADD	HL,BC
    adc #<.MODE_TABLE
    sta temp_word
    lda #0
    adc #>.MODE_TABLE
    sta temp_word+1
    jmp [*temp_word]                ; JP	(HL)		; Jump to initialization routine

_get_mode::
    lda .mode                       ; LD	HL,#.mode
                                    ; LD	E,(HL)
    rts                             ; RET
