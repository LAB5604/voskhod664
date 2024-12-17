//THIS IS JUST A TEMPLATE OF USER INTERRUPT CONTROL
//MOVE THIS FILE FROM BSP TO YOU PROJECT INCLUDE FOLDER FIRST!
/*
 * Anlogic Softcore Interrupt Controller
 * For Anlogic Softcore BSP
 * Engineer: Xiaoyu HONG
 */

#ifndef INTERRUPT_H_
#define INTERRUPT_H_
#include "maxcore.h"
#include <stdint.h>

#define SIC_TRIG    *((volatile uint32_t*)(CLSIC_BASE+0x0000))
#define INT_MASK    *((volatile uint32_t*)(CLSIC_BASE+0x2000))
#define INT_EVENT   *((volatile uint32_t*)(CLSIC_BASE+0x2004))


void SoftISP();
void TimerISP();
void ExternalISP();
void ExceptionHandler();



static inline uint32_t GetSwInt()
{
  return SIC_TRIG;
}
static inline uint32_t SetSwInt()
{
  SIC_TRIG=0xFFFFFFFF;
}
static inline uint32_t ClrSwInt()
{
  SIC_TRIG=0x00000000;
}
static inline void TurnOnInterrupt(uint32_t int_sel)
{
  asm(
		"csrw mie, %[src]" 
    :[src]"=r"(int_sel)
);
}
static inline uint32_t TurnOffInterrupt()
{
  uint32_t temp;
  asm(
		"csrrwi %[temp],mie, 0x00000" 
    :[temp]"=r"(temp));
  return temp;
}

static inline  void ClrIntEvent(uint32_t data)
{
  INT_EVENT=data;
}
static inline uint32_t GetIntEvent()
{
  return INT_EVENT;
}
static inline void SetIntMask(uint32_t data)
{
  INT_MASK=data;
}
static inline uint32_t GetIntMask()
{
  return INT_MASK;
}


void irqCallback()
{
  uint32_t temp;
  asm(
      "csrr %[dest] , mcause"
      :[dest]"=r"(temp)
      );
    if(temp==0x80000003)
      SoftISP();
    else if(temp==0x80000007)//filter out timer int
      TimerISP();
    else if(temp==0x8000000B)//filter out External int
      ExternalISP();
    else ExceptionHandler();
};



#endif /* INTERRUPT_H_ */
