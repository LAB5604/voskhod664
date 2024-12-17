//THIS IS JUST A TEMPLATE OF USER INTERRUPT CONTROL
//MOVE THIS FILE FROM BSP TO YOU PROJECT INCLUDE FOLDER FIRST!
/*
 * Anlogic Softcore CSR Custom Bus 
 * For Anlogic Softcore BSP
 * Engineer: Xiaoyu HONG
 */

#ifndef CSR_BUS_H
#define CSR_BUS_H
#include <stdint.h>

// #define CSRBUS_ADDR 0xB08
// #define CSRBUS_DATA 0xB09


static inline void CSRBusWrite(uint32_t DATA)
{
  asm volatile(
		"csrw 0xB09, %[src]" 
    :[src]"=r"(DATA)
    );
}
static inline uint32_t CSRBusRead()
{
  uint32_t temp;
    asm volatile(
        "csrr %[dest] , 0xB09"
        :[dest]"=r"(temp)
        );
  return temp;
}
static inline uint32_t CSRBusRaW(uint32_t DATA)
{
  uint32_t temp;
    asm volatile(
        "csrrw %[dest] , 0xB09, %[src]"
        : [dest] "=r"(temp)
        : [src] "r"(DATA));
    return temp;
}

static inline void CSRBusAddrWrite(uint32_t ADDR)
{
  asm volatile(
		"csrw 0xB08, %[src]" 
    :[src]"=r"(ADDR)
    );
}
static inline uint32_t CSRBusAddrRead()
{
  uint32_t temp;
    asm volatile(
        "csrr %[dest] , 0xB08"
        :[dest]"=r"(temp)
        );
  return temp;
}




#endif /* CSR_BUS_H */
