		.z180

#target		bin
#code		TEXT, $100

		org	$100

main:		ld	ix, input
		ld	iy, output
		call	tokenise
		halt

;; to be hooked by debugger
input:		ld	a, $1A
		ret

;; to be hooked by debugger
output:		ret

#include	"token.asm"
