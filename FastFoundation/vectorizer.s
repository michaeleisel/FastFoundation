//Copyright (c) 2018 Michael Eisel. All rights reserved.

// assume it's not going to run over a bad page boundary, assume it's aligned

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
// load masks
movi vrepquote, #0x22

mov scratch_reg, 0x4080
movk scratch_reg, 0x1020, lsl 16
movk scratch_reg, 0x0408, lsl 32
movk scratch_reg, 0x0201, lsl 48
dup stepmask_raw.2d, scratch_reg

mov scratch_reg, 0xffff
movk scratch_reg, 0xffff, lsl 16
movk scratch_reg, 0xffff, lsl 32
movk scratch_reg, 0xffff, lsl 48

ins halfmask_raw.d[0], x31 // hope this is zero
ins halfmask_raw.d[1], scratch_reg

iter:
subs length, length, #16
cc a1:
ldur q2, [string]

cmeq vchrs0, vchrs0, vrepquote
cc a2:
and vchrs0, vchrs0, stepmask
cc a3:

movi.16b vadds_raw, #0
cc a4:
addv b0, vchrs0_raw.8b
cc a5:
and vchrs0, vchrs0, halfmask_raw.16b
cc a6:
addv b9, vchrs0
cc a7:
ins vadds_raw.b[1], adder_scratch.b[0]

cc a8:
str h0, [out]
cc a9:
add out, out, #2
cc a10:
add string, string, #16
cc a11:
b.hi iter
cc a12:
ret
