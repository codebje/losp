;; Symbol storage and lookup
;;
;; A symbol is an interned string. It may be an atom, with no further value associated, or it may be a variable, bound
;; to some value. LISP 1.5 used p-lists to bind different kinds of value, such that a name could be mapped to one value
;; if used as an operand, and another if used as an operator. It also used distinct versions of EXPR (lambda defs) that
;; didn't evaluate its operands - LISP 1.5 didn't have macros.
;;
;; Scheme does away with the p-list distinction: an identifier in operator or operand position is evaluated in the same
;; way.
;;
;; Losp also evaluates all identifiers in the same way: an environment maps names to values. Values can be used as
;; functions if they are a LAMBDA form, otherwise they result in an evaluation error.
;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; symbol_intern - add or retrieve a symbol
;;
;; Symbols are stored as shared interned strings
;;
;; The interned strings are in a trie: each node of the trie is a list whose car is the character at that branch of
;; the trie and whose cdr is a list of sub-nodes. The root is just a list of the initial characters of all interned
;; strings, and is a GC root. A leaf node has no children. The "value" of a symbol is a pointer to its final character
;; cell, which may not be a leaf node (eg, "hi" and "high" will share their first two nodes) but which will uniquely
;; identify that symbol.
;;
;; It would not be practical to translate from a symbol value to the symbol's label in this model. One resolution to
;; this might be to have a specific kind of sub-node for the symbol that's easily distinguished from child nodes, and
;; that contains the full label. This, unfortunately, duplicates all labels.
;;
;; in:		de	the symbol's token, a NUL-terminated string
;; out:		hl	the symbol's node (as a 14-bit pointer)
;;
#local
symbol_intern::
		ld	hl, interns		; initially (interns) is nil
		; can't have (interns) nil - it has to point to or be an empty list
		; could have it as a fake cell

		; a node looks like ( #\<char> . ( ( child-node ) . ( ( child-node) ... ) ) )
		; the symbol's node is always ( #\x00 . nil ), the cellptr value distinguishes them
		; just "sym" interned looks like: ( ( #\s ( #\y ( #\m ( #\0 ) ) ) ) )
		;      ┏━━━┳━━━┓   ┏━━━┳━━━┓
		;      ┃ s ┃ ├─╂───┨ ┬ ┃ 0 ┃
		;      ┗━━━┻━━━┛   ┗━┿━┻━━━┛
		;                    │
		;                  ┏━┷━┳━━━┓   ┏━━━┳━━━┓
		;                  ┃ y ┃ ├─╂───┨ ┬ ┃ 0 ┃
		;                  ┗━━━┻━━━┛   ┗━┿━┻━━━┛
		;                                │
		;                              ┏━┷━┳━━━┓   ┏━━━┳━━━┓
		;                              ┃ m ┃ ├─╂───┨ ┬ ┃ 0 ┃
		;                              ┗━━━┻━━━┛   ┗━┿━┻━━━┛
		;                                            │
		;                                          ┏━┷━┳━━━┓
		;                                          ┃ 0 ┃ 0 ┃
		;                                          ┗━━━┻━━━┛
		; looking up "sum" will start with the word at interns pointing to the #\s cell
		; match "s" with "s", 

		; de points to current character
		; hl points to cellptr of next node to compare against (or nil, if no match)
		; if (hl) is nil, make a pair holding ( (de) . nil ) and store its cellptr in (hl)
		; if (de) is null, return (hl) as the result
		; hl <- (hl)
		; if (de) equals (car hl), increment de, set hl <- &(cdar hl), loop
		; else set hl <- &(cdr hl), loop
search:		ld	a, (de)
		or	a			; if (de) is zero the symbol is found
		jr	z, found

		ld	bc, (hl)
		ld	a, b
		and	$3f			; mask off type bits
		or	c
		jr	nz, compare		; bc = 0, need to allocate

		ld	a, (de)
		push	de
		push	hl
		ld	de, $4000		; bit 14 set in cdr -> character data in car
		ld	b, 0
		ld	c, a
		call	allocate		; hl = ( #\(de) . nil )
		ex	de, hl
		pop	hl
		ld	(hl), de
		pop	de			; compare will now succeed

		; at this point (hl) = ( #\<char> child ... )
compare:	ld	a, (hl)
		inc	hl
		ld	h, (hl)
		ld	l, a
		add	hl, hl
		add	hl, hl			; hl points to the pair's contents

		ld	a, (de)
		cp	(hl)			; the character data is now in (hl)
		jr	z, match

match:		inc	hl
		inc	hl
		inc	de

found:		ld	a, (hl)			; the symbol's node is where hl points
		inc	hl
		ld	h, (hl)
		ld	l, a
		ret

interns:	.dw	0			; the head of the list - will be allocated if nil
#endlocal

;;
;; Option 1 - Hash function on the string, walk linked list of hash codes
;;
;;		┏━━━┳━━━┓   ┏━━━┳━━━┓   ┏━━━┳━━━┓
;;		┃ ┬ ┃ ├─╂───┨ ┬ ┃ ├─╂───┨ ┬ ┃ 0 ┃
;;              ┗━┿━┻━━━┛   ┗━┿━┻━━━┛   ┗━┿━┻━━━┛
;;		  │           │           │
;; 		┏━┷━┳━━━┓   ┏━┷━┳━━━┓   ┏━┷━┳━━━┓
;;		┃ x ┃ ┬ ┃   ┃ y ┃ ┬ ┃   ┃ z ┃ ┬ ┃
;;              ┗━━━┻━┿━┛   ┗━━━┻━┿━┛   ┗━━━┻━┿━┛
;;		      │           │           │
;;
;; Each hash code's cdr is followed by a list of symbols colliding on that hash code; for each pair the car points to
;; the symbol's label as a list of characters.
;;
;; Advantages:
;;    quick comparison of each hash code
;;    easy to implement
;; Disadvantages:
;;    performance is linear in no. of symbols plus length of symbol, a relatively small gain over #syms x sym-length
;;
;; Option 2 - Trees
;;
;; Several flavours present themselves here. One would be a binary tree of hashes, balanced for best results. Another
;; would be a trie-like structure, the symbols "are", "am", "army", "who", and "was" would produce:
;;
;;   ( ( #\a ( #\r ( #\e )
;;                 ( #\m #\y ) )
;;           ( #\m ) )
;;     ( #\w ( #\h #\o )
;;           ( #\a #\s ) ) )
;;
;; The worst case performance of this is O(symbol-chars x symbol-length) but typical performance will be much better
;; due to the typically sparse nature of a symbol space.
;;
;; Advantages:
;;    Lookup performance likely to be much better
;; Disadvantages:
;;    Insert and removal code more complex
;;
;; The list elements may need more depth to 'em; single symbol "sym" looks like:
;;   ( ( ( #\s . ? )
;;       ( ( #\y . ? )
;;         ( ( #\m . ? ) ) ) ) )
;; That is, the car of each node is not a character but a pair of ( character . symbol-value )
;; One option would be to have the second half of the pair point to the previous character, allowing the symbol label
;; to be recovered in reverse. Symbol bindings don't happen in this structure, so the "value" is an identity for the
;; interned string, not used in evaluation.
