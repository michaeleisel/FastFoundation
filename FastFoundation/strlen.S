//Copyright (c) 2018 Michael Eisel. All rights reserved.

.section    __TEXT,__text,regular,pure_instructions
.build_version ios, 12, 0
.p2align    2

#define orig_string x2
#define curr_string x0
#define reg_max x3
#define reg_vec x4
#define zero_idx x5
#define ands_buffer x6

#define buffer v0
#define zeros v1
#define zero_count q2
#define simd_max b3

.globl _ffo_strlen
_ffo_strlen:
.cfi_startproc
mov orig_string, curr_string

aligner:
ands ands_buffer, curr_string, #0xf
b.eq vector
ldrb w3, [curr_string], #1
cbz w3, found_one
b aligner

movi zeros.4s, #0x0 // is eor faster?

// todo: play with loop unrolling
.p2align
vector:
ldr q0, [curr_string]
add curr_string, curr_string, #0x10 // for some reason, adding explicitly is faster than adding in ldr
// apple's version tests whether or not the min of the vector is 0. but for some strange reason, the following two lines do the job faster
cmeq.16b buffer, buffer, zeros
umaxv b3, v0.16b
mov reg_max, v3.d[0]
cbz reg_max, vector

// the correct chunk has been found
mov reg_vec, v0.d[0]
sub curr_string, curr_string, 16
cbnz reg_vec, add_left

mov reg_vec, v0.d[1]
add curr_string, curr_string, 8

add_left:
rbit reg_vec, reg_vec
clz zero_idx, reg_vec
add curr_string, curr_string, zero_idx, lsr #3

found:
sub curr_string, curr_string, x2
ret

found_one:
sub curr_string, curr_string, x2
sub curr_string, curr_string, 1
ret

.cfi_endproc
