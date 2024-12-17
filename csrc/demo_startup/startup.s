.align 2
.equ VGA_TXT_BASE,    0x00008000
.equ VGA_COLOR_BASE,  0x00009000
.equ VGA_BLINK_BASE,  0x0000A000
.equ DEFAULT_COLOR,   0x17      #默认前景色白 背景蓝 经典AMI BIOS配色

.section .text
.global _start

_start:
        #csrr t0, mhartid
        #bnez t0, halt
        li t0, 25000000
L0:                             #loop for delay
        addi t0, t0, -1
        bgt t0, zero, L0 
clean:                          #clean display ram
        la a0, VGA_TXT_BASE
        la a1, VGA_COLOR_BASE
        li t0, 2400
        li t2, DEFAULT_COLOR    #set default color
L1:
        sb zero, 0(a0)          #字符均设置为ASCII=00
        sb t2, 0(a1)            #字符颜色设置为默认颜色
        addi a0, a0, 1
        addi a1, a1, 1
        addi t0, t0, -1
        bgt t0, zero, L1
clean_blank:
        la a0, VGA_BLINK_BASE
        li t0, 300
L2:
        sb zero, 0(a0)          #闪烁位均设置为0，不闪烁
        addi a0, a0, 1
        addi t0, t0, -1
        bgt t0, zero, L2        
puts:
        la a0, msg          #load first address of msg
        la a1, VGA_TXT_BASE
        li t0, 80
L3:
        lbu t1, 0(a0)  
        sb t1, 0(a1)
        addi a0, a0, 1
        addi a1, a1, 1
        addi t0, t0, -1
        bgt t0, zero, L3

halt:   j halt


.section .rodata
msg:             ################################################################################
        .string "    Version 0.0 Voskhod664 Salyut1 platform BIOS Copyright LAB5604 2018-2023.   "