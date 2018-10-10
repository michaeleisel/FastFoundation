//Copyright (c) 2018 Michael Eisel. All rights reserved.

// assume it's not going to run over a bad page boundary, assume it's aligned

#define vrepquote v0.16b
#define vchrs0 v1.16b
#define vchrs1 v2.16b
#define vres0 v3.16b
#define vres1 v4.16b
#define stepmask_raw v5
#define stepmask stepmask_raw##.16b

#define str x0
#define length x1
#define out x2
#define end x3


// #0x8040201008040201
.section    __TEXT,__text,regular,pure_instructions
.build_version ios, 12, 0
.globl    _f1                     ; -- Begin function f1
.p2align    2

_process_chars:
    movi vrepquote, #0x22
    // movi v0.2d, #0
    mov x0, 0x0201
    movk x0, 0x0804, lsl 16
    movk x0, 0x2010, lsl 32
    movk x0, 0x8040, lsl 48
    dup stepmask_raw.2d, x0
    // mov
    // movi stepmask_raw.2D, 1:2:3:4:5:7:8// #0x8040201008040201
    add end, str, length
    iter:
    cmp str, end
    b.ge _end
    // ld1 {vchrs0}, [str]! // specify alignment with "@128" // explore other instructions that mean something similar; explore putting the pointer into an simd register ; explore loading more registers here
    cmeq vres0, vchrs0, vrepquote
    and vres0, vres0, stepmask
    addv B4, vres0
    mov x1, v4.D[0] // vres1[0]
    // mov x1, vres1
    // and vres0, stepmask
    // and vres0
    // vmeq

    // ands vstepmask

    ; cmeq  vres0, vchrs1, vrepchr



    ; move data of str into vector, aligned, and add 128 to str
    ; if
    ; combined:
    ; cmpeq
    ; mask with vector
    ; add up elements
    ; if it's > 0:
    ;   move it, plus the index, to the data
    ;   add 1 to the count
    ;   if count == 16:
    ;     ; move to stack?
    _end:
    ret
