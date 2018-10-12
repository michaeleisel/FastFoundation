//Copyright (c) 2018 Michael Eisel. All rights reserved.

// assume it's not going to run over a bad page boundary, assume it's aligned

// .file    1 "/Users/michaeleisel/Documents/Projects/FastFoundation" "/Users/michaeleisel/Documents/Projects/FastFoundation/FastFoundation/vectorizer.s"
#define vadds_raw v0 // can't move from here
#define vadds vadds_raw##.16b
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
#define adder_scratch v9
// #define halfmask halfmask_raw##.16b
#define cc ;

#define string x0
#define length x1
#define out x2
#define scratch_reg x3

.section    __TEXT,__text,regular,pure_instructions
.build_version ios, 12, 0
.globl    _process_chars
.p2align    2

_process_chars:
.cfi_startproc
// load masks
movi vrepquote, #0x22

mov scratch_reg,  0x4080
movk scratch_reg, 0x1020, lsl 16
movk scratch_reg, 0x0408, lsl 32
movk scratch_reg, 0x0102, lsl 48
dup stepmask_raw.2d, scratch_reg

mov scratch_reg, 0xffff
movk scratch_reg, 0xffff, lsl 16
movk scratch_reg, 0xffff, lsl 32
movk scratch_reg, 0xffff, lsl 48

ins halfmask_raw.d[0], x31 // hope this is zero
ins halfmask_raw.d[1], scratch_reg


iter:
// .loc    1 55 0
subs length, length, #32
ldp q2, q3, [string], #32

cmeq vchrs0, vchrs0, vrepquote
and vchrs0, vchrs0, stepmask
cmeq vchrs1, vchrs1, vrepquote
and vchrs1, vchrs1, stepmask

addv b9, vchrs1_raw.8b
and vchrs1, vchrs1, halfmask_raw.16b
addv b10, vchrs1
shl v10.2d, v10.2d, #8
orr v9.8b, v9.8b, v10.8b

addv b0, vchrs0_raw.8b
and vchrs0, vchrs0, halfmask_raw.16b
addv b11, vchrs0
shl v11.2d, v11.2d, #8
orr v0.8b, v0.8b, v11.8b
shl v9.2d, v9.2d, #16
orr v0.8b, v0.8b, v9.8b

str s0, [out], #4
b.hi iter
ret
.cfi_endproc
