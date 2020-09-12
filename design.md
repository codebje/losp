S-expression

    atom: [a-zA-Z0-9\-\_'], starts with letter, max 30 chars, case sensitive
    cons cell: ( s-expr . s-expr )

list notation:

    ( s-expr-1 s-expr-2 ... s-expr-n )
    == ( s-expr-1 . ( s-expr-2 . ... ( s-expr-n . NIL ) ... ) )

form:
    constant    form's evaluation is the constant
                0, 'a', "foo"
    variable    form's evaluation is the eval of the s-expr bound to the variable
                identifier (= atom)
    application form's evaluation is the evaluation of the body after argument substitution
                identifier
                lambda (variable ...) form
                label identifier function       recursive fn needs to know its own name
    conditional form's evaluation is the evaluation of the lhs of the first pair whose rhs is T

s-expressions of forms:

    constant            (quote constant)
    variable            variable
    fn[x;..]            (fn* x* ...)
    [p1->e1;...;pn->en] (cond (p1* e1*) ... (pn* en*))

    identifier => atom
    lambda = (lambda (var* ...) form*)
    label = (label identifier* function*)

intrinsics:

    cons
    car/cdr
    atom
    NIL = ( )

    car/cdr special form: fn beginning with c, ending with r, non-empty sequence of a/d
        cadr = car[cdr[...]]
        cddr = cdr[cdr[...]]
        etc

    eq[x;y] = T iff x & y are the same atom

definable in-language:
    equal[x;y] = [atom[x] -> [atom[y] -> eq[x;y]; T -> F];
                  equal[car[x];car[y]] -> equal[cdr[x];cdr[y]];
                  T -> F]
    (label equal (lambda (x y) (cond
        ((atom x) (cond ((atom y) (eq x y)) ((quote T) (quote F))))
        ((atom y) (quote F))
        ((equal (car x) (car y)) (equal (cdr x) (cdr y)))
        ((quote T) (quote F)))))

    subst[x;y;z] = [equal[y;z] -> x; atom[z] -> z; T -> cons[
            subst[x;y;car[z]];subst[x;y;cdr[z]]]]
    (label subst (lambda (x y z) (cond
        ((equal (y z)) x)
        ((atom z) z)
        ((quote T) (cons (subst x y (car z)) (subst x y (cdr z)))))))

    null[x] = [atom[x] -> eq[x;NIL]; T -> F]
    (lambda (x) (cond ((atom x) (eq x NIL)) ((quote T) (quote F))))

    append[x;y] = [null[x] -> y; T -> cons[car[x]; append[cdr[x];y]]]
    (label append (lambda (x y) (cond
        ((null x) y)
        ((quote T) (cons (car x) (append (cdr x) y))))))

    member[x;y] = [null[y] -> F;
                   equal[x;car[y]] -> T;
                   T -> member[x;cdr[y]]]
    (label member (lambda (x y) (cond
        ((null y) (quote F))
        ((equal x (car y)) (quote T))
        ((quote T) (member x (cdr y))))))

    zip[x;y;a] = [null[x] -> a; T -> cons[cons[car[x];car[y]];zip[cdr[x];cdr[y];a]]]
    (label zip (lambda (x y a) (cond
        ((null x) a)
        ((quote T) (cons (cons (car x) (car y)) (zip (cdr x) (cdr y) a))))))

    assoc[x;a] = [equal[caar[a];x]->car[a]; T->assoc[x;cdr[a]]]
    (label assoc (lambda (x a) (cond
        ((equal (caar a) x) (car a))
        ((quote T) (assoc x (cdr a))))))

    sub2[a;z] = [null[a]->z;eq[caar[a];z]->cdar[a];T->sub2[cdr[a];z]]
    sublis[a;y] = [atom[y]->sub2[a;y];T->cons[sublis[a;car[y]];sublis[a;cdr[y]]]]
    (label sub2 (lambda (a z) (cond
        ((null a) z)
        ((eq (caar a) z) (cdar a))
        ((quote T) (sub2 (cdr a) z)))))
    (label sublis (lambda (a y) (cond
        ((atom y) (sub2 a y))
        ((quote T) (cons (sublis a (car y)) (sublis a (cdr y)))))))

    evalquote[fn;x] = apply[fn;x;NIL]
    (fn x) = (apply fn x NIL)

    apply[fn;x;a] = [
        atom(x) -> [eq[fn;CAR] -> caar[x];
                    eq[fn;CDR] -> cdar[x];
                    eq[fn;CONS] -> cons[car[x];cadr[x]];
                    eq[fn;ATOM] -> atom[car[x]];
                    eq[fn;EQ] -> eq[car[x];cadr[x]];
                    T -> apply[eval[fn;a];x;a]];
        eq[car[fn];LAMBDA] -> eval[caddr[fn];zip[cadr[fn];x;a]];
        eq[car[fn];LABEL] -> apply[caddr[fn];x;cons[cons[cadr[fn];caddr[fn]];a]]]

    eval[e;a] = [atom[e] -> cdr[assoc[e;a]];
                 atom[car[e]] ->
                    [eq[car[e];QUOTE] -> cadr[e];
                     eq[car[e];COND] -> evcon[cdr[e];a];
                     T -> apply[car[e];evlis[cdr[e];a];a]];
                 T -> apply[car[e];evlis[cdr[e];a];a]]

    evcon[c;a] = [eval[caar[c];a] -> eval[cadar[c];a];
                  T -> evcon[cdr[c];a]]

    evlis[m;a] = [null[m] -> NIL;
                  T -> cons[eval[car[m];a];evlis[cdr[m];a]]]

operation:

    environment maps atoms to s-expressions
    simple linked list allows nested environments to easily point to outer
    but are slow to traverse - a tree structure with a "parent" pointer may be better

    p-list - property lists, one per symbol
            APVAL -> constant
            EXPR -> function def'n
            SUBR -> pointer to machine code
            FEXPR/FSUBR -> special forms
    a-list - bind lists

    atomic symbols are on an object list, pointing to p-list entries - classic lisp used a hash map

    cons cell - 16-bit 'a' value, 16-bit 'd' pointer
    all cons cells are therefore 32-bits, and pointers are only 14 bits: use high bit(s) and can just shift/add/tst
    mark-and-sweep GC using one bit: from active roots mark all active, then sweep others into garbage
    data cells (16-bit ints, strings) in a different region of memory - mark via bitmap
    active roots: object list (atoms), stack in use...

cautions:
    Lisp 1.5 is dynamically scoped, what bollocks
    each recurse inside params in eval should add a new layer of lexical scope
    each close param should remove a layer
    most layers have no vars - so don't want to push on a stack for every paren
    instead each _lexical_ binding has a depth on it, exiting a lexical depth 'pops' the value
    eg
        (define foo                             // 'foo' is bound at depth 1
            (lambda (x)                         // 'x' is not bound until call site
                (+ x 5)))                       // trouble is 'foo' should now have popped

        (let foo                                // 'let' makes sense this way, 'define' doesn't
            (lambda (x) (x + 5))
            (foo 3))

    what scope should 'define' have? if it's the parent scope (depth - 1) then this sort of works

thoughts:
    continuation passing style has appeal - continuation objects are trivialised
    implementation level, it's `jp (hl)` over `ret`

scheme:
    identifiers alphanum, plus extended: ! $ % & * + - . / : < = > ? @ ^ _ ~
    must start with a char that can't begin a number - *, / ergo fine; + and - alone are identifiers
    comments ; to eol
    quote is ', not QUOTE
    static scope

    disjoint types: boolean? pair? symbol? number? char? string? vector? port? procedure?

plan:
    pair: 32 bits, two 14 bit pointers; car bit 15 is for GC marking. car bit 14 indicates if cdr is a pointer or a
    16-bit number. cdr bit 14 indicates if car is a character/byte in bits 7-0 or a pointer.

    	0 _ 0	regular pair	both halves are pointers to other pairs
	0 _ 1	character data	car 7-0 contains an ascii byte, cdr is a pointer as usual
	1 x x	16-bit number	cdr half contains a 16-bit signed numeric value, not a pointer

    potential exists to use cdr bit 15 to further differentiate

    strings, symbols are lists of characters. easy over efficient. characters and 8-bit unsigned data are identical.

    procedures are expected to be a list whose car is a list of variable names to be bound and whose cdr is a list of
    expressions to evaluate: `lambda` is equivalent to `quote`

    Atom pointers could be a relative index into the atom space. The atom space is at most 16kb in size due to the use
    of 14-bit pointers. The initial atom space is 16kb - not sure yet how to allow a program to shrink this. Runtime
    shrinking requires that atoms aren't in the space to be shrunk. Using the MMU might work: it could potentially be
    a lot of remapping, but just writing the BBR is pretty fast - a full 64k of program data in 0x10000 - 0x1ffff with
    any space below BDOS and above the interpreter available for atoms, less a 4k window into the program data.

    Environments are pairs of (name, data) in a linked list, eg
    	( (NIL NIL) (ten 10) (lambda <intrinsic>) )

    allocator - no GC - init. a memory space to cons cells linked to each other as free list
    symbols ?
    reader - tokenise by FSM
