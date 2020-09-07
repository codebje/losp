# Lisp Operating System Program

Programming the TRS-20 in assembly gets old fairly fast. This project is the inevitable attempt at a Lisp interpreter and perhaps compiler that comes in every inquisitive developer's life. Maybe it'll be a viable alternative base to CP/M, hence the sad pun name.

## Decision log

  - Lisp, because functional is king, but effective static types require more space than I think I can handle
  - Borrowing Scheme (R7RS) syntax, because it's a good starting point
  - Static scope - so borrowing a fair chunk of Scheme's semantics too
  - 16-bit signed integer math, no floating point, no fixed point, no bigint
  - Separate lexer and parser - probably a bit bigger and a bit slower, but a lot more maintainable
  - Add _ in numbers for spacing to Scheme's syntax
