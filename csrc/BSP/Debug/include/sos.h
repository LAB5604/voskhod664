
/*
 * Anlogic Softcore debug facility
 * For Anlogic Softcore BSP
 * Engineer: Xiaoyu HONG
 */
//Attention, to enable debug, please initilize UART first!!! 

#ifndef SOS_H_
#define SOS_H_
#include "anl_printf.h"

#ifndef INTERRUPT_H_ //INTERRUPT NOT IN USE
void irqCallback()
{
    uint32_t temp;
    anl_printf("Core is DEAD!\r\n");
    asm(
        "csrr %[dest] , mcause"
        :[dest]"=r"(temp)
        );
    anl_printf("MCAUSE is 0x%x\r\n",temp);
    asm(
        "csrr %[dest] , mepc"
        :[dest]"=r"(temp)
        );
    anl_printf("MEPC is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 15*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x1 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 14*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x5 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 13*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x6 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 12*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x7 in stack is 0x%x\r\n",temp);    
    asm(
        "lw %[dest] , 11*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x10 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 10*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x11 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 9*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x12 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 8*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x13 in stack is 0x%x\r\n",temp);     
    asm(
        "lw %[dest] , 7*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x14 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 6*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x15 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 5*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x16 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 4*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x17 in stack is 0x%x\r\n",temp);    
    asm(
        "lw %[dest] , 3*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x28 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 2*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x29 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 1*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x30 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 0*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x31 in stack is 0x%x\r\n",temp);    
    anl_printf("Debug Rpt End, R.I.P.\r\n");
    while(1);
};
#else
void ExceptionHandler()
{
    uint32_t temp;
    anl_printf("Core is DEAD!\r\n");
    asm(
        "csrr %[dest] , mcause"
        :[dest]"=r"(temp)
        );
    anl_printf("MCAUSE is 0x%x\r\n",temp);
    asm(
        "csrr %[dest] , mepc"
        :[dest]"=r"(temp)
        );
    anl_printf("MEPC is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 15*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x1 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 14*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x5 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 13*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x6 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 12*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x7 in stack is 0x%x\r\n",temp);    
    asm(
        "lw %[dest] , 11*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x10 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 10*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x11 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 9*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x12 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 8*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x13 in stack is 0x%x\r\n",temp);     
    asm(
        "lw %[dest] , 7*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x14 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 6*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x15 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 5*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x16 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 4*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x17 in stack is 0x%x\r\n",temp);    
    asm(
        "lw %[dest] , 3*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x28 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 2*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x29 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 1*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x30 in stack is 0x%x\r\n",temp);
    asm(
        "lw %[dest] , 0*4(sp)"
        :[dest]"=r"(temp)
        );
    anl_printf("x31 in stack is 0x%x\r\n",temp);    
    anl_printf("Debug Rpt End, R.I.P.\r\n");
    while(1);
};
#endif

#endif 