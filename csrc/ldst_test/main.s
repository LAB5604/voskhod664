.align 2

.section .text
.global _start

_start:
    la sp, _sp
    li t0, 0
    li t1, 1
    li t2, 2
    li t3, 3
    j push
pop:
    ld a0, 0(sp)
    ld a1, 8(sp)
    ld a2, 16(sp)
    ld a3, 24(sp)
    addi sp, sp, 32
    j halt
push:
    addi sp, sp, -32
    sd t0, 0(sp)
    sd t1, 8(sp)
    sd t2, 16(sp)
    sd t3, 24(sp)
    j pop
halt:
        j halt
                                        