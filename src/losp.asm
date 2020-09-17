		.z180

#target		bin

#code		TEXT, $100

#data		PROG, TEXT_end

		.align	4
program:	equ	$

#code		TEXT

		org	$100

		ld	sp, (6)
		jp	main
test:		call	alloc_init
		ld	bc, $8038
loop:		call	allocate
		call	print_state
		djnz	loop
		dec	c
		jr	nz, loop
		jp	0

state_msg:	.text	'BC='
state_bc:	.text	'????, allocated='
state_hl:	.text	'????',13,10,'$'
print_state:	ld	a, b
		call	bin_to_hex
		ld	(state_bc), de
		ld	a, c
		call	bin_to_hex
		ld	(state_bc+2), de
		ld	a, h
		call	bin_to_hex
		ld	(state_hl), de
		ld	a, l
		call	bin_to_hex
		ld	(state_hl+2), de
		push	bc
		ld	de, state_msg
		ld	c, 9
		call	5
		pop	bc
		ret

main:		ld	ix, input
		ld	iy, output
		call	tokenise
		cp	TOK_EOF
		jr	z, done
		ld	de, parse_error
		ld	c, 9
		call	5
done:		halt

input:		ld	hl, (ptr)
		ld	a, (hl)
		inc	hl
		ld	(ptr),hl
		ret

output:		cp	TOK_EOF+1
		jr	nc, err
		or	a
		ret	z
		ld	bc, hl
		ld	hl, jumps
		dec	a
		ld	d, 0
		add	a
		ld	e, a
		add	hl, de
		ld	a, (hl)
		inc	hl
		ld	h, (hl)
		ld	l, a
		jp	(hl)

err:		ld	de, parse_error
		ld	c, 9
		jp	5			; return from here to the tokeniser

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; bin_to_hex - convert an 8-bit binary value to hex digits
;;
;; https://stackoverflow.com/questions/22838444/convert-an-8bit-number-to-hex-in-z80-assembler
;;
;; in:		a	value
;; out:		de	hex digits
#local
bin_to_hex::	push	af
		push	bc
		ld	c, a
		call	shift
		ld	e, a
		ld	a, c
		call	convert
		ld	d, a
		pop	bc
		pop	af
		ret

shift:		rra		; shift higher nibble to lower
		rra
		rra
		rra
convert:	or	a, $f0
		daa		; I've no idea if this will work on a Z180...
		add	a, $a0
		adc	a, $40
		ret
#endlocal

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; variables

ptr:		dw	src
src:		.text	'(print #\a #\x7a "hello world")', $1a
parse_error:	.text	'parse error', 13, 10, '$'

jumps:		.dw	p_ident
		.dw	p_true
		.dw	p_false
		.dw	p_number
		.dw	p_char
		.dw	p_string
		.dw	p_lparen
		.dw	p_rparen
		.dw	p_hparen
		.dw	p_quote
		.dw	p_bquote
		.dw	p_comma
		.dw	p_comma_at
		.dw	p_period
		.dw	p_eof

#local
p_ident::	ld	de, msg
		ld	c, 9
		jp	5
msg:		.text	'ident',13,10,'$'
#endlocal

#local
p_true::	ld	de, msg
		ld	c, 9
		jp	5
msg:		.text	'true',13,10,'$'
#endlocal

#local
p_false::	ld	de, msg
		ld	c, 9
		jp	5
msg:		.text	'false',13,10,'$'
#endlocal

#local
p_number::	ld	de, msg
		ld	c, 9
		jp	5
msg:		.text	'number',13,10,'$'
#endlocal

#local
p_char::	ld	de, msg
		ld	a, c
		ld	(val), a
		ld	c, 9
		jp	5
msg:		.text	'char: '
val:		.text	'?',13,10,'$'
#endlocal

#local
p_string::	ld	de, msg
		ld	c, 9
		jp	5
msg:		.text	'string',13,10,'$'
#endlocal

#local
p_lparen::	ld	de, msg
		ld	c, 9
		jp	5
msg:		.text	'left-paren',13,10,'$'
#endlocal

#local
p_rparen::	ld	de, msg
		ld	c, 9
		jp	5
msg:		.text	'right-paren',13,10,'$'
#endlocal

#local
p_hparen::	ld	de, msg
		ld	c, 9
		jp	5
msg:		.text	'hash-paren',13,10,'$'
#endlocal

#local
p_quote::	ld	de, msg
		ld	c, 9
		jp	5
msg:		.text	'quote',13,10,'$'
#endlocal

#local
p_bquote::	ld	de, msg
		ld	c, 9
		jp	5
msg:		.text	'backquote',13,10,'$'
#endlocal

#local
p_comma::	ld	de, msg
		ld	c, 9
		jp	5
msg:		.text	'comma',13,10,'$'
#endlocal

#local
p_comma_at::	ld	de, msg
		ld	c, 9
		jp	5
msg:		.text	'comma-at',13,10,'$'
#endlocal

#local
p_period::	ld	de, msg
		ld	c, 9
		jp	5
msg:		.text	'period',13,10,'$'
#endlocal

#local
p_eof::		ld	de, msg
		ld	c, 9
		jp	5
msg:		.text	'EOF',13,10,'$'
#endlocal

#include	"alloc.asm"
#include	"token.asm"
#include	"symbols.asm"

