//Copyright (c) 2018 Michael Eisel. All rights reserved.

.globl _cpy_strlen
_cpy_strlen:
and    x1, x0, #0xfffffffffffffff0
ldr    q0, [x1]
adr    x3, #-0xc8                ; ___lldb_unnamed_symbol4$$libsystem_platform.dylib
ldr    q2, [x3], #0x10
and    x2, x0, #0xf
sub    x3, x3, x2
ldr    q1, [x3]
orr.16b v0, v0, v1
b      loop               ; <+52>
nop
nop
nop
loop_early:
ldr    q0, [x1, #0x10]!
loop:
uminv.16b b1, v0
fmov   w2, s1
cbnz   w2, loop_early           ; <+48>
eor.16b v1, v1, v1
cmhi.16b v0, v0, v1
orr.16b v0, v0, v2
uminv.16b b1, v0
fmov   w2, s1
sub    x0, x1, x0
add    x0, x0, x2
ret
