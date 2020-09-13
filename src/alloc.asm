;; Allocator and garbage collector
;;
;; Every object is either a pair or an atom. Pairs consume 32 bits of space, thus pointers only require 14 bits each.
;; A pair contains two pointers; in the car pointer bit 15 is used for GC marking of the pair.
;;
;; Version 1 uses the simplest approach to atoms - if bit 14 of car is set, then cdr is a signed 16-bit number, not a
;; pointer. If it's reset, then bit 14 of cdr indicates if the car is a pointer to a pair (reset) or contains an 8-bit
;; character or byte value. Identifiers and strings are indistinguishable and interchangeable, that is, the expression
;;	("cons" 'a 'b)
;; is equivalent to
;;	(cons 'a 'b)
;;
;; As an extra short-cut NIL is represented as a zero pointer value; the zeroth cell is reserved for NIL's value.
;;
;; The expression (define "pi" (3 14159) would be represented as:
;;
;;	┏━━━┳━━━┓   ┏━━━┳━━━┓   ┏━━━┳━━━┓
;;	┃ ┬ ┃ ├─╂───┨ ┬ ┃ ├─╂───┨ ┬ ┃ 0 ┃
;;	┗━┿━┻━━━┛   ┗━┿━┻━━━┛   ┗━┿━┻━━━┛
;;	  │           │           │
;;	  │           │         ┏━┷━┳━━━┓   ┏━━━┳━━━┓
;;	  │           │         ┃ ┬ ┃ ├─╂───┨ ┬ ┃ 0 ┃
;;	  │           │         ┗━┿━┻━━━┛   ┗━┿━┻━━━┛
;;	  │           │           │           │
;;	  │           │         ┏━┷━━━━━┓   ┏━┷━━━━━┓
;;	  │           │         ┃     3 ┃   ┃ 14159 ┃
;;	  │           │         ┗━━━━━━━┛   ┗━━━━━━━┛
;;	  │           │
;;	  │         ┏━┷━┳━━━┓   ┏━━━┳━━━┓
;;	  │         ┃ p ┃ ├─╂───┨ i ┃ 0 ┃
;;	  │         ┗━━━┻━━━┛   ┗━━━┻━━━┛
;;	  │
;;	┏━┷━┳━━━┓   ┏━━━┳━━━┓   ┏━━━┳━━━┓   ┏━━━┳━━━┓   ┏━━━┳━━━┓   ┏━━━┳━━━┓
;;	┃ d ┃ ├─╂───┨ e ┃ ├─╂───┨ f ┃ ├─╂───┨ i ┃ ├─╂───┨ n ┃ ├─╂───┨ e ┃ 0 ┃
;;	┗━━━┻━━━┛   ┗━━━┻━━━┛   ┗━━━┻━━━┛   ┗━━━┻━━━┛   ┗━━━┻━━━┛   ┗━━━┻━━━┛
;;

;; Allocator variables
free_list:	.dw	program

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; alloc_init	initialise the allocator
;;
;; This sets up the free list pointer to the base of memory and constructs a
;; chain of free pairs up to the top of program memory.
;;
#local
alloc_init::
		ld	de, program			; the start of program space
		ld	hl, (6)
		or	a				; clear carry flag
		sbc	hl, de				; hl = count of bytes to fill
		srl	h				; cf = h[0], h = h >> 1, h[7] = 0
		rr	l				; cf = l[0], l = l >> 1, l[7] = cf
		srl	h				; ie, shift hl right, twice => /4
		rr	l
		ld	b, l
		ld	c, h				; this will leave 1kb for a stack
		ld	hl, program>>2
		ld	(free_list), hl			; reset the free list
		inc	hl
		ld	ix, program+4
		ld	de, 4

		xor	a
		ld	(ix-4), a
		ld	(ix-3), a

		; each iteration sets car to zero and cdr to point to the previous word
loop:		ld	(ix+0), a
		ld	(ix+1), a
		ld	(ix-2), l
		ld	(ix-1), h

		add	ix, de
		inc	hl

		djnz	loop
		dec	c
		jr	nz, loop

		;; the last free block terminates the list
		ld	(ix-2), a
		ld	(ix-1), a

		ret
#endlocal

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; allocate	allocate a new pair
;;
;; `allocate` will allocate a new pair from the free list. If there are no more
;; free pairs to allocate, `allocate` will print an error message and terminate
;; the program.
;;
;; The contents of the pair will be cleared to zero.
;;
;; out:		hl	the allocated pair
;;
#local
allocate::
		push	af
		push	de
		push	ix
		ld	hl, (free_list)
		add	hl, hl
		add	hl, hl
		ld	a, h
		or	l
		jr	z, oom
		push	hl
		pop	ix
		ld	d, (ix+3)
		ld	e, (ix+2)
		ld	(free_list), de
		xor	a
		ld	(ix+0), a
		ld	(ix+1), a
		ld	(ix+2), a
		ld	(ix+3), a
		pop	ix
		pop	de
		pop	af
		ret

oom:		ld	de, oom_msg
		ld	c, 9
		call	5
		jp	0

oom_msg:	.text	'ENOMEM',13,10,'$'
#endlocal
