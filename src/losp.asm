		.z180

#target		bin

#code		TEXT, $100

#data		PROG, TEXT_end

		.align	4
program:	equ	$

#code		TEXT

		org	$100

		ld	sp, (6)
test:		call	alloc_init
		halt

main:		ld	ix, input
		ld	iy, output
		call	tokenise
		halt

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

ptr:		dw	src
src:		.text	'(print "hello world")', $1a
parse_error:	.text	'parse error', 13, 10, $1a

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
		ld	c, 9
		jp	5
msg:		.text	'char',13,10,'$'
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
