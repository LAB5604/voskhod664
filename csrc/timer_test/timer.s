.align 2
.equ VGA_TXT_BASE,    0x00008000
.equ VGA_COLOR_BASE,  0x00009000
.equ VGA_BLINK_BASE,  0x0000A000

.equ MTIME,           0x40000000
.equ MTIMECMP,        0x40000008

.equ DEFAULT_COLOR,   0x17      #默认前景色白 背景蓝 经典AMI BIOS配色

.section .text
.global _start

_start:
        mv t0, zero
        li a0, MTIME
        sd t0, 0(a0)        #mtime寄存器设置为0
        addi t0, t0, 1800
        sd t0, 8(a0)        #mtimecmp寄存器设置为比原始值大1800
        la t0, timer_isp
        csrw mtvec, t0      #mtvec为中断入口地址
        li t0, 0x80         
        csrw mie, t0        #mie寄存器开启mti中断
        li t0, 0x1888
        csrw mstatus, t0    #mstatus寄存器开全局中断
L0:
        j L0 
timer_isp:
        mret

