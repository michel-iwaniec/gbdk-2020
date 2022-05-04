# sm83 specific Makefile

TOPDIR = ../../..

THIS = mos6502

ASSRC = __sdcc_indirect_jsr.s _memcpy.s _strcpy.s \
	_divuint.s _divsint.s _modsint.s _moduint.s \
	_mulint.s

CSRC =	_memmove.c _memset.c _ret.c abs.c

include $(TOPDIR)/Makefile.common

AS = $(AS_6500)

include ../Makefile.port


