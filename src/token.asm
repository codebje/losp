; Scheme tokeniser

TOK_PARTIAL	equ	0		; The next token is not ready yet
TOK_IDENTIFIER	equ	1		; An identifier was recognised
TOK_TRUE	equ	2		; A TRUE boolean was recognised
TOK_FALSE	equ	3		; A FALSE boolean was recognised
TOK_NUMBER	equ	4		; A number was recognised
TOK_CHARACTER	equ	5		; A character was recognised
TOK_STRING	equ	6		; A string was recognised
TOK_LPAREN	equ	7		; A left paren was recognised
TOK_RPAREN	equ	8		; A right paren was recognised
TOK_HASH_PAREN	equ	9		; A #( sequence was recognised
TOK_QUOTE	equ	10		; A single quote was recognised
TOK_BACKQUOTE	equ	11		; A backquote was recognised
TOK_COMMA	equ	12		; A comma was recognised
TOK_COMMA_AT	equ	13		; A ,@ sequence was recognised
TOK_PERIOD	equ	14		; A period was recognised
TOK_EOF		equ	15		; The end of the file was reached

ERR_UNEXPECTED	equ	128		; Unexpected character given
ERR_TOO_LONG	equ	129		; Input token too long
ERR_OVERFLOW	equ	130		; Number too large for 16 bits
ERR_EARLY_EOF	equ	131		; EOF was encountered mid-token

ERR_INTERNAL	equ	255		; Tokeniser is broken

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; tokenise - extract tokens from an input character stream
;;
;; tokenise will call the provided input function repeatedly until
;; it returns EOF. For each character obtained from the input function
;; zero or more tokens will be passed to the output function. TOK_EOF
;; will never be passed to the output function: it is instead returned
;; to the caller.
;;
;; The input function should return the next character to process in
;; A. The character 1A is treated as an end-of-file marker in CP/M
;; tradition.
;;
;; The output function will be given the token type in A. For some
;; token types an additional argument will be in HL:
;;			TOK_IDENTIFIER	a pointer to a string
;;			TOK_NUMBER	the value
;;			TOK_CHARACTER	the value in l
;;			TOK_STRING	a pointer to a string
;;
;; in:		IX	The input function
;;		IY	the output funtion
;; out:		A	TOK_EOF or ERR_xxx
#local
tokenise::
		ld	(input), ix
		ld	(output), iy
		ld	hl, INIT
		ld	(state), hl
		xor	a
		ld	(has_char), a

run_fsm:	call	get_input
		ld	b, a
		ld	de, 6
		ld	ix, (state)

fsm_loop:	ld	a, (ix+0)
		or	a
		jr	z, fsm_match
		cp	b
		jr	z, fsm_match
		add	ix, de
		jr	fsm_loop

fsm_match:	ld	hl, (ix+1)
		ld	(state), hl
		ld	a, (ix+3)
		tst	$80			; if bit 7 was set, it's an error
		ret	nz
		or	a
		push	ix
		push	bc
		call	nz, go_output		; if it's not zero, output a token
		pop	bc
		pop	ix
		ld	hl, (ix+4)
		ld	a, l
		or	h
		call	nz, userfn		; call the user function if set
		jr	run_fsm			; go back for more input

userfn:		ld	a, b
		jp	(hl)

fsm		macro	char, state, token, fn
		.db	&char		; +0
		.dw	&state		; +1
		.db	&token		; +3
		.dw	&fn		; +4
		endm

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DONE state
;;
;; This FSM node is an error to reach. It should be set as the target
;; state when tokenisation is complete, ie, when EOF has been input
;; at an appropriate time. The done user function will execute a
;; successful return.
;;
DONE:		fsm	0, DONE, ERR_INTERNAL, 0

done:		ld	a, TOK_EOF
		pop	hl
		ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; INIT state
;;
;; token = identifier | boolean | number | character | string
;;	 | ( | ) | #( | #u8( | ' | ` | , | ,@ | .
;;
;; This FSM node matches single-character tokens and hands off to 
;; other nodes to recognise the longer or less unambiguous tokens.
;;
;; <identifier>			= <initial> <subsequent>*
;;				| <vertical line> <symbol element>* <vertical line> 	NOT IMPLEMENTED
;;				| <peculiar identifier>
;; <initial>			= [a-zA-Z!$%&*/:<=>?^_~]
;; <peculiar identifier> 	= <explicit sign>
;;				| <explicit sign> <sign subsequent> <subsequent>*
;;				| <explicit sign> . <dot subsequent> <subsequent>*
;;				| . <dot subsequent> <subsequent>*
;; <explicit sign>		= + | -
;; <dot subsequent>		= <sign subsequent> | .
;; <sign subsequent>		= <initial> | <explicit sign> | @
;;
;; When encountering a + or -, the following token determines the
;; next state to enter. If it is a digit, a base 10 number should
;; follow. Otherwise, it should be a delimiter for a single
;; character identifier, a sign subsequent, or a period followed
;; by a sign subsequent or period.
;;
;; ascii: !"#$%&'()*+,-./0-9:;<=>?@A-Z[\]^_`a-z{|}~
;; numeric: 0-9
;; special: .
;; invalid: #',[\]`{|}
;;
;; When encountering a period, the following token determines the
;; next state to enter. A delimiter indicates TOK_PERIOD, else the
;; same rules as for a period after an explicit sign apply.
;;
#local
INIT::		fsm	9, INIT, 0, 0			; tab - ignore
		fsm	10, INIT, 0, 0			; lf - ignore
		fsm	13, INIT, 0, 0			; cr - ignore
		fsm	32, INIT, 0, 0			; space - ignore
		fsm	'"', STRING, 0, tok_string	; start of a string
		fsm	'#', HASH, 0, 0			; many branches from here
		fsm	'+', INIT, 0, tok_plus		; ident or number
		fsm	',', INIT, 0, tok_comma		; comma or comma-at
		fsm	'-', INIT, 0, tok_minus		; ident or number
		fsm	';', COMMENT, 0, 0		; comment to eol
		fsm	$1A, DONE, TOK_EOF, done	; EOF: successful tokenisation
		fsm	39, INIT, TOK_QUOTE, 0		; single quote
		fsm	'(', INIT, TOK_LPAREN, 0	; '(' stands alone
		fsm	')', INIT, TOK_RPAREN, 0	; ')' stands alone
		fsm	'.', INIT, 0, tok_period	; special identifier or period
		fsm	'`', INIT, TOK_BACKQUOTE, 0	; '`' stands alone
		fsm	'@', DONE, ERR_UNEXPECTED, 0	; @ illegal here
		fsm	'[', DONE, ERR_UNEXPECTED, 0
		fsm	'\', DONE, ERR_UNEXPECTED, 0
		fsm	']', DONE, ERR_UNEXPECTED, 0
		fsm	$7b, DONE, ERR_UNEXPECTED, 0	; {
		fsm	'|', DONE, ERR_UNEXPECTED, 0
		fsm	'}', DONE, ERR_UNEXPECTED, 0
		fsm	0, INIT, 0, token		; anything else - digit or ident

token_err::	ld	a, ERR_UNEXPECTED
		pop	hl				; pop the fsm return address
		ret					; return from the tokeniser

token:		cp	'~'+1
		jr	nc, token_err			; > '~' is illegal
		cp	'!'
		jr	c, token_err			; < '!' is illegal
		cp	'9'+1
		jp	nc, ident			; > '9' means identifier
		cp	'0'
		jp	c, ident			; < '0' means identifier

		ld	(sign), a			; bit 7 determines sign: clear for positive
		sub	'0'				; it's a digit - convert to binary
		ld	(numeric), a			; and reset the numeric input
		xor	a
		ld	(numeric+1), a
		ld	hl, BASE10
		ld	(state), hl			; next state is base-10 input
		ret

tok_string:	xor	a
		ld	(string), a			; NUL terminate the string
		dec	a
		ld	(stridx), a			; string index will become zero
		ret

;; A plus or a minus stores the sign, then checks the next input character.
;; It may be an identifier, a number, or invalid input.
tok_plus:	ld	(sign), a			; bit 7 determines sign: zero for positive
		jr	plus_or_minus
tok_minus:	cpl
		ld	(sign), a			; bit 7 set for negative
plus_or_minus:	call	peek_input
		;; special: .
		cp	'.'
		jr	z, sign_period_id
		;; numeric: 0-9
		cp	'0'
		jr	c, sign_ident
		cp	'9'+1
		jr	nc, sign_ident
		ld	hl, 0				; positive or negative base-10 number
		ld	(numeric), hl
		ld	hl, BASE10
		ld	(state), hl			; next state is base-10 input
		ret

		; <explicit sign> . encountered
		; the next character MUST be a <dot subsequent>, else it's an error
sign_period_id:	ld	(string+1), a
		ld	a, (sign)
		tst	$80
		jr	z, $+3			; skip cpl
		cpl
		ld	(string), a		; (string) = "+." or "-." now
		call	get_input		; eat the '.'
		call	get_input		; get the <dot subsequent> hopeful
		call	dot_subsequent		; test it
		jp	z, token_err		; anything else - unexpected input error
		ld	(string+2), a		; save it
		xor	a
		ld	(string+3), a		; NUL terminate
		ld	a, 2
		ld	(stridx), a		; index of last character written
		ld	hl, IDENT		; do <subsequent>* next
		ld	(state), hl
		ret

tok_period:	call	peek_input		; check to see what's next
		call	is_delimiter
		jr	nz, period_ident
		ld	a, TOK_PERIOD
		jp	go_output

		; might be an identifier beginning with a period?
period_ident:	ld	a, '.'
		ld	(string), a
		call	get_input		; committed to this input now
		call	dot_subsequent		; check for . | <sign subsequent>
		jp	z, token_err
		ld	(string+1), a
		xor	a
		ld	(string+2), a
		ld	a, 1
		ld	(stridx), a
		ld	hl, IDENT
		ld	(state), hl
		ret

sign_ident:	;; followed by a delimiter: identifier of one character
		call	is_delimiter
		jr	z, peculiar_id			; the IDENT node will terminate on delimiter

		call	sign_subsequent
		jp	z, token_err

;; ZF set if A is not in the <dot subsequent> production
dot_subsequent:	cp	'.'
		jr	z, subs_ok
sign_subsequent:
		; invert test: rule out invalid characters, then just range test
		ld	hl, invalid
		ld	bc, invalid_size
		cpir
		jr	z, subs_error
		cp	'!'
		jr	c, subs_error			; less than ! is invalid
		cp	'~'+1
		jr	nc, subs_error			; greater than ~ is invalid
subs_ok:	or	a				; it's not zero - clear ZF
		ret
subs_error:	xor	a				; set ZF
		ret

		; reload the sign character and enter the ident code path
peculiar_id:	ld	a, (sign)
		tst	$80
		jr	z, ident
		cpl

ident:		ld	hl, IDENT
		ld	(state), hl			; then go into identifier state
		ld	(string), a			; store the first byte of the identifier
		xor	a
		ld	(string+1), a			; NUL terminate
		ld	(stridx), a			; reset string index - preincremented in append
		ret

tok_comma:	call	peek_input
		cp	'@'
		jr	z, comma_at
		ld	a, TOK_COMMA
		jp	go_output

comma_at:	call	get_input
		ld	a, TOK_COMMA_AT
		jp	go_output

invalid: 	.text	"#',[\]`{|}"
invalid_size:	equ	$ - invalid

#endlocal

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; STRING state
;;
;; <string> = " <string element>* "
;; <string element> = <any character other than " or \>
;;		    | \a | \b | \t | \r | \n | \" | \\ | \x<hex>
;;		    | \<intraline whitespace>*<newline><intraline whitespace>*
;;
;; This FSM node matches strings. Escaping is handled by STR_ESCAPE.
;; An EOF inside a string is an error.
;;
STRING::	fsm	'"', INIT, 0, string_done
		fsm	'\', STR_ESCAPE, 0, 0		; escape sequence
		fsm	$1A, DONE, ERR_EARLY_EOF, 0	; EOF is bad in a string
		fsm	0, STRING, 0, string_append

string_done:	ld	hl, string
		ld	a, TOK_STRING
		call	go_output
		ret

string_append:	ld	b, a
		ld	hl, string
		ld	a, (stridx)
		inc	a
		ld	(stridx), a
		cp	127
		jr	nc, string_overrun
		add	l
		ld	l, a
		adc	h
		sub	l
		ld	h, a
		ld	a, b
		ld	(hl), a
		inc	hl
		xor	a
		ld	(hl), a				; NUL terminate
		ret

string_overrun:	ld	a, ERR_TOO_LONG
		pop	hl
		ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; STR_ESCAPE state
;;
;; <string element> = ...
;;		    | \a | \b | \t | \r | \n | \" | \\ | \x<hex>
;;		    | \<intraline whitespace>*<newline><intraline whitespace>*
;;
;; This FSM node matches string escapes. The implementation here does
;; not support hex escapes, \a, \b, or escaped newlines.
;;
STR_ESCAPE::	fsm	'"', STRING, 0, string_append	; \" inserts a "
		fsm	'\', STRING, 0, string_append	; \\ inserts a \
		fsm	'n', STRING, 0, str_append_lf	; \n inserts LF
		fsm	'r', STRING, 0, str_append_cr	; \r inserts CR
		fsm	't', STRING, 0, str_append_ht	; \t inserts a tab
		;fsm	'x', HEXONE, 0, 0		; \xHH inserts a byte by hex code
		;fsm	32, STR_ESCAPE, 0, 0		; \<tab|space>*<lf|crlf><tab|space>* inserts CR+LF
		;fsm	9, STR_ESCAPE, 0, 0
		;fsm	13, ...
		fsm	0, DONE, ERR_UNEXPECTED, 0	; anything else is invalid

str_append_ht:	ld	a, 9
		jr	string_append
str_append_lf:	ld	a, 10
		jr	string_append
str_append_cr:	ld	a, 13
		jr	string_append

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; HASH state
;;
;; <boolean>		= #t | #f
;; <character>		= #\<character>
;;			| #\<character name>	NOT IMPLEMENTED
;;			| #\x<hex>		NOT IMPLEMENTED
;; <character name>	= alarm | backspace | delete | escape | newline
;;			| null | return | space | tab
;; <vector>		= #(			NOT IMPLEMENTED
;; <bytevector>		= #u8(			NOT IMPLEMENTED
;; <nested comment>	= #| .. |#		NOT IMPLEMENTED
;; <directive>		= #!...			NOT IMPLEMENTED
;; <radix 2>		= #b
;; <radix 8>		= #o			NOT IMPLEMENTED
;; <radix 10>		= #d
;; <radix 16>		= #x
;;
HASH:		fsm	't', INIT, TOK_TRUE, 0
		fsm	'f', INIT, TOK_FALSE, 0
		fsm	'\', CHAR_ESCAPE, 0, 0
		fsm	'b', BASE2, 0, zero_num
		fsm	'd', BASE10, 0, zero_num
		fsm	'x', BASE16, 0, zero_num
		fsm	0, DONE, ERR_UNEXPECTED, 0

zero_num:	ld	bc, 0
		ld	(numeric), bc
		ld	a, '+'
		ld	(sign), a
		ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CHAR_ESCAPE state
;;
;; <character>		= #\<character>
;;			| #\<character name>	NOT IMPLEMENTED
;;			| #\x<hex>		NOT IMPLEMENTED
;; <character name>	= alarm | backspace | delete | escape | newline
;;			| null | return | space | tab
;;
;; A full implementation needs to peek ahead on x, a, b, e, n, r, s, t.
;;
CHAR_ESCAPE:	fsm	$1A, DONE, ERR_UNEXPECTED, 0	; can't EOF here
		fsm	0, INIT, 0, character		; _everything else_ literally as-is

character:	ld	l, a
		ld	a, TOK_CHARACTER
		jp	go_output			; let go_output ret for me

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; COMMENT state
;;
;; Ignore everything to end of line or end of file.
;;

COMMENT:	fsm	10, INIT, 0, 0
		fsm	13, INIT, 0, 0
		fsm	$1A, DONE, TOK_EOF, 0
		fsm	0, COMMENT, 0, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Number parsers
;;
#local
BASE2::		fsm	0, BASE2, 0, parse
parse:		call	is_delimiter
		jr	z, number_done
		cp	'_'
		ret	z
		cp	'0'
		jr	z, digit
		cp	'1'
		jp	nz, token_err
digit:		sub	'0'
		ld	hl, (numeric)
		add	hl, hl
		jr	c, overflow
		or	l
		ld	l, a
		ld	(numeric), hl
		ret
#endlocal

#local
BASE10::	fsm	0, BASE10, 0, parse
parse:		call	is_delimiter
		jr	z, base10_done
		cp	'_'
		ret	z
		cp	'0'
		jp	c, token_err
		cp	'9'+1
		jp	nc, token_err
digit:		sub	'0'
		ld	hl, (numeric)
		add	hl, hl			; hl = hl * 2
		jr	c, overflow
		ld	bc, hl
		add	hl, hl			; hl = hl * 4
		jr	c, overflow
		add	hl, hl			; hl = hl * 8
		jr	c, overflow
		add	hl, bc			; hl = hl * 10
		jr	c, overflow
		ld	c, a
		ld	b, 0
		add	hl, bc			; hl = hl * 10 + input
		jr	c, overflow
		ld	(numeric), hl
		ret

base10_done:	ld	a, (sign)		; check the sign flag
		and	$80			; also clears carry flag for 16-bit sbc
		ld	b, a			; save the sign flag
		jr	z, check_sign		; positive number: don't negate it
		ld	hl, 0
		ld	de, (numeric)
		sbc	hl, de
		ld	(numeric), hl

		; for a positive number the sign bit should not be set
		; for a negative number it should be
check_sign:	ld	a, (numeric+1)
		and	$80
		xor	b
		jr	nz, overflow		; if the sign bits differ the number overflowed
		jr	number_done
#endlocal

; Pop these between BASE10 and BASE16 to be reachable from BASE2, BASE10, and BASE16
overflow:	ld	a, ERR_OVERFLOW
		pop	hl
		ret

number_done:	ld	hl, INIT
		ld	(state), hl
		ld	hl, (numeric)
		ld	a, TOK_NUMBER
		jp	go_output

#local
BASE16::	fsm	0, BASE16, 0, parse
parse:		call	is_delimiter
		jr	z, number_done
		cp	'_'
		ret	z
		cp	'0'
		jp	c, token_err		; < '0' is an error
		cp	'9'+1
		jr	c, digit		; '0' < a < '9'+1 is a decimal digit
		cp	'a'
		jr	c, char			; < 'a' should be lower case
		sub	'a' - 'A'		; convert to lower case
char:		cp	'A'
		jp	c, token_err		; < 'A' is an error
		cp	'F'+1
		jp	nc, token_err		; > 'F' is an error
		sub	'A' - '9' - 1		; convert to 0-9 scale
digit:		sub	'0'
		ld	hl, (numeric)
		add	hl, hl			; hl=hl*2
		jr	c, overflow
		add	hl, hl			; hl=hl*4
		jr	c, overflow
		add	hl, hl			; hl=hl*8
		jr	c, overflow
		add	hl, hl			; hl=hl*16
		jr	c, overflow
		add	l
		ld	l, a
		ld	(numeric), hl
		ret

digits:		.text	'0123456789ABCDEF'

#endlocal


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; IDENT state
;;
;; <identifier> 	= <initial> <subsequent>*
;;
;; This state matches <subsequent>*, terminating on <delimiter>. Any character other than
;; a <delimiter> or <subsequent> is an error. End of input will also terminate the identifier.
;;
;; <initial> 		= <letter>
;;			| <special initial>
;; <letter> 		=  a | b | c | ... | z
;; 			| A | B | C | ... | Z
;; <special initial> 	= ! | $ | % | & | * | / | : | < | = | > | ? | ^ | _ | ~
;; <subsequent> 	= <initial> | <digit> | <special subsequent>
;; <digit> 		= 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
;; <explicit sign> 	= + | -
;; <special subsequent> = <explicit sign> | . | @
;; <delimiter> 		= <whitespace> | <vertical line> | ( | ) | " | ;
;;
IDENT:		; <delimiter> terminates the identifier
		fsm	9, INIT, 0, ident_done
		fsm	10, INIT, 0, ident_done
		fsm	13, INIT, 0, ident_done
		fsm	32, INIT, 0, ident_done
		fsm	'|', INIT, 0, ident_push	; return the '|' to the input buffer
		fsm	'(', INIT, 0, ident_push
		fsm	')', INIT, 0, ident_push
		fsm	'"', INIT, 0, ident_push
		fsm	';', INIT, 0, ident_push
		; EOF also terminates the identifier; let it get processed by INIT afterwards
		fsm	$1A, INIT, 0, ident_push
		; pull out low sequence count error characters
		fsm	'#', DONE, ERR_UNEXPECTED, 0
		fsm	39, DONE, ERR_UNEXPECTED, 0
		fsm	',', DONE, ERR_UNEXPECTED, 0
		fsm	'[', DONE, ERR_UNEXPECTED, 0
		fsm	'\', DONE, ERR_UNEXPECTED, 0
		fsm	'`', DONE, ERR_UNEXPECTED, 0
		fsm	']', DONE, ERR_UNEXPECTED, 0
		fsm	$7B, DONE, ERR_UNEXPECTED, 0	; {
		fsm	'}', DONE, ERR_UNEXPECTED, 0
		; the comparisons are easier done by range checks now
		; anything left between '!' and '~' is a valid input
		fsm	0, IDENT, 0, ident_check

ident_check:	cp	'!'
		jp	c, token_err
		cp	'~'+1
		ld	b, a
		jp	c, string_append		; re-use string append

ident_push:	call	push_input
ident_done:	ld	hl, string
		ld	a, TOK_IDENTIFIER
		call	go_output
		ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; peek_input looks at the next available input character without consuming it.
peek_input:	ld	a, (has_char)
		or	a
		jr	z, load_input
		ld	a, (next_char)
		ret

load_input:	ld	a, $ff
		ld	(has_char), a
		.db	$cd			; call **
input:		.dw	0			; replaced with input function
		ld	(next_char), a
		ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get_input gets the next available input character.
;; one that has been tested via peek_input will be returned if available.
;; one that has been rejected by push_input will be returned if available.
;; otherwise the input provider function will be called.
get_input:	call	peek_input
		xor	a
		ld	(has_char), a
		ld	a, (next_char)
		ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; push_input returns a character to the input buffer
;; it is an error to call this after peek_input but before get_input.
push_input:	ld	(next_char), a
		ld	a, 1
		ld	(has_char), a
		ret

next_char:	.db	0
has_char:	.db	0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; is_delimiter tests for a delimiter in A; ZF is set on match
is_delimiter:	ld	hl, delimiters
		ld	bc, delimcount
		cpir
		ret

;; The set of delimiters - includes end of input
delimiters:	.text	9, 10, 13, ' ()|";', $1A
delimcount:	equ	$ - delimiters

;; trampolines to input, output, and FSM node functions
go_output:	.db	$c3		; jp **
output:		.dw	0
go_state:	.db	$c3
state:		.dw	INIT

sign:		.db	0
numeric:	.dw	0
stridx		.db	0
string:		.ds	129,0		; 1 byte extra for NUL

PLUS_IDENT:	.text	'+',0
MINUS_IDENT:	.text	'-',0

#endlocal
