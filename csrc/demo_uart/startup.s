.align 2
.section .init;
.globl _start;
.type _start,@function

_start:
.option push
.option norelax
	la gp, __global_pointer$
.option pop
	la sp, _sp

	/* Clear bss section */
	la a0, __bss_start
	la a1, _end
	bgeu a0, a1, 2f
1:
	sd zero, (a0)
	addi a0, a0, 8
	bltu a0, a1, 1b
2:

    call _init
    call main

#ifdef SIMULATION
    li x26, 0x01
#endif

loop:
    j loop