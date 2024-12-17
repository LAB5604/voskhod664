
/*
 * Anlogic Softcore GPIO
 * For Anlogic Softcore BSP
 * Engineer: Xiaoyu HONG
 */

#ifndef GPIO_H_
#define GPIO_H_

#include <stdint.h>
typedef struct
{
  volatile uint32_t INPUT;
  volatile uint32_t OUTPUT;
  volatile uint32_t OUTPUT_ENABLE;
  volatile uint32_t GPIO_INTMASK;
} Gpio_Reg;


#endif /* GPIO_H_ */


