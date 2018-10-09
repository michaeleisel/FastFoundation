.section    __TEXT,__text,regular,pure_instructions
.build_version ios, 12, 0
.globl    _cool                     ; -- Begin function f1
.p2align    2
_cool:
    tst    x0, #0xf
    # b.eq   0x1cb533014               ; <+36>
    ldrb   w4, [x0], #0x1
    ldrb   w5, [x1], #0x1
    subs   x3, x4, x5
    ccmp   w4, #0x0, #0x4, eq
    #b.ne   0x1cb532ff0               ; <+0>
    mov    x0, x3
    ret
