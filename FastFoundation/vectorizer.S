//Copyright (c) 2018 Michael Eisel. All rights reserved.

// assume it's not going to run over a bad page boundary, assume it's aligned

#define adder_scratch v0
#define vrepquote v1.16b
#define vchrs0_raw v2
#define vchrs0 vchrs0_raw##.16b
#define vchrs1_raw v3
#define vchrs1 vchrs1_raw##.16b
#define vchrs2_raw v4
#define vchrs2 vchrs2_raw##.16b
#define vchrs3_raw v5
#define vchrs3 vchrs3_raw##.16b
#define stepmask_raw v7
#define stepmask stepmask_raw##.16b
#define halfmask_raw v8

#define string x0
#define length x1
#define out x2
#define end x3
#define scratch_reg x4


.section    __TEXT,__text,regular,pure_instructions
.build_version ios, 12, 0
.globl    _process_chars
.p2align    2

_process_chars:
// load masks
movi vrepquote, #0x22

.macro fill64 reg:req, s0:req, s1:req, s2:req, s3:req
mov \reg, \s3
movk \reg, \s2, lsl 16
movk \reg, \s1, lsl 32
movk \reg, \s0, lsl 48
.endm

fill64 scratch_reg, 0x0102, 0x0408, 0x1020, 0x4080
dup stepmask_raw.2d, scratch_reg

fill64 scratch_reg, 0xffff, 0xffff, 0xffff, 0xffff
ins halfmask_raw.d[0], x31 // hope this is zero
ins halfmask_raw.d[1], scratch_reg

add end, string, length
iter:

st4 {vchrs0, vchrs1, vchrs2, vchrs3}, [string]

cmeq vchrs0, vchrs0, vrepquote
and vchrs0, vchrs0, stepmask
cmeq vchrs1, vchrs1, vrepquote
and vchrs1, vchrs1, stepmask
cmeq vchrs2, vchrs2, vrepquote
and vchrs2, vchrs2, stepmask
cmeq vchrs3, vchrs3, vrepquote
and vchrs3, vchrs3, stepmask

movi.16b adder_scratch, #0

.macro sum vchrs_8:req, vchrs:req, num:req, num_times_two:req, num_times_two_plus_one:req
addv b0, \vchrs_8
and \vchrs, \vchrs, halfmask_raw.16b
ushr adder_scratch.8h, adder_scratch.8h, #8
addv b0, \vchrs
ushr adder_scratch.4s, adder_scratch.4s, #16
.endm

sum vchrs0_raw.8b, vchrs0, 0, 0, 1
sum vchrs1_raw.8b, vchrs1, 1, 2, 3
sum vchrs2_raw.8b, vchrs2, 2, 4, 5
sum vchrs3_raw.8b, vchrs3, 3, 6, 7

str d0, [out]
add out, out, #8
add string, string, #64
cmp string, end
b.ge _end
b iter
_end:
ret
