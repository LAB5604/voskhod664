/*
 * Anlogic Softcore Peripheral Address Define File
 * For Anlogic Softcore BSP
 * Engineer: Xiaoyu HONG
 */

#ifndef __MAXCORE_H__
#define __MAXCORE_H__


#define CLSIC_BASE 0xF0200000

#define UART      ((Uart_Reg*)(0xF0210000))
#define GPIO_A    ((Gpio_Reg*)(0xF0210100))
#define SPI       ((Spi_Reg*) (0xF0210200))
#define I2C       ((I2c_Reg*) (0xF0210300))		



#endif /* __CORE_H__ */
