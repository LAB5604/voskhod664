#ifndef I2C_H_
#define I2C_H_

#include <stdint.h>
/*
/////////////////////////////////////////////////////////////////////
////                                                             ////
////  Include file for OpenCores I2C Master core                 ////
////                                                             ////
////  File    : oc_i2c_master.h                                  ////
////  Function: c-include file                                   ////
////                                                             ////
////  Authors: Richard Herveille (richard@asics.ws)              ////
////           Filip Miletic                                     ////
////                                                             ////
////           www.opencores.org                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2001 Richard Herveille                        ////
////                    Filip Miletic                            ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
*/

/*
 * Wrapped Wishbone I2C to 32bit APB
 * For Anlogic Softcore
 * Engineer: Xiaoyu HONG
 */
#define RXACK 0x80
#define BUSY  0x40
#define TIP   0x02
#define IRQ   0x01   
#define I2C_WRITE 0x00
#define I2C_READ  0x01
typedef struct
{
  volatile uint32_t I2CCTRL;
  volatile uint32_t I2CCMDSTR;
  volatile uint32_t DUMMY;
  volatile uint32_t I2CTRBUF;
} I2c_Reg;
	
#define OC_I2C_EN (1<<7)        /* Core enable bit:                   */
                                /*      1 - core is enabled           */
                                /*      0 - core is disabled          */
#define OC_I2C_IEN (1<<6)       /* Interrupt enable bit               */
                                /*      1 - Interrupt enabled         */
                                /*      0 - Interrupt disabled        */
                                /* Other bits in CR are reserved      */

/* ----- Command register bits                                        */
 
#define OC_I2C_STA (1<<7)       /* Generate (repeated) start condition*/
#define OC_I2C_STO (1<<6)       /* Generate stop condition            */
#define OC_I2C_RD  (1<<5)       /* Read from slave                    */
#define OC_I2C_WR  (1<<4)       /* Write to slave                     */
#define OC_I2C_ACK (1<<3)       /* Acknowledge from slave             */
                                /*      1 - ACK                       */
                                /*      0 - NACK                      */
#define OC_I2C_IACK (1<<0)      /* Interrupt acknowledge              */

/* ----- Status register bits                                         */

// #define OC_I2C_RXACK (1<<7)     /* ACK received from slave            */
//                                 /*      1 - ACK                       */
//                                 /*      0 - NACK                      */
// #define OC_I2C_BUSY  (1<<6)     /* Busy bit                           */
// #define OC_I2C_TIP   (1<<1)     /* Transfer in progress               */
// #define OC_I2C_IF    (1<<0)     /* Interrupt flag                     */


static void i2c_init(I2c_Reg *reg, uint16_t psc, uint8_t i2c_enable,uint8_t int_enable)
{
	uint32_t reg_config=0;
    uint8_t ctrl=0;
    reg_config=(uint32_t) psc;
    if(i2c_enable!=0)ctrl=ctrl | OC_I2C_EN;
    if(int_enable!=0)ctrl=ctrl | OC_I2C_IEN;
	reg_config=reg_config|(ctrl<<16);
    reg->I2CCTRL=reg_config;
	return;
}
static inline uint8_t i2c_flag_get(I2c_Reg *reg,uint8_t req)
{
    return ((reg->I2CCMDSTR>>8)&req)!=0;
}
static uint8_t i2c_get_rxack(I2c_Reg *reg)
{
    while(i2c_flag_get(reg,TIP)); 
    return ((reg->I2CCMDSTR>>8)&RXACK);
}
static uint8_t i2c_data_transmit(I2c_Reg *reg,uint8_t data)
{
    while(i2c_flag_get(reg,TIP)); 
    reg->I2CTRBUF=data;
    reg->I2CCMDSTR=0x10;
    return (i2c_get_rxack(reg)!=0);
}
static uint8_t i2c_data_receive(I2c_Reg *reg)
{
    while(i2c_flag_get(reg,TIP)); 
    reg->I2CCMDSTR=0x20;
    while(i2c_flag_get(reg,TIP)); 
    return reg->I2CTRBUF;
}
static uint8_t i2c_write_addr(I2c_Reg *reg,uint8_t addr,uint8_t dir)
{
    while(i2c_flag_get(reg,TIP)); 
    reg->I2CTRBUF=(addr|dir);
    reg->I2CCMDSTR=0x90;
    return (i2c_get_rxack(reg)!=0);
}
static inline void i2c_send_stop(I2c_Reg *reg)
{
    while(i2c_flag_get(reg,TIP)); 
    reg->I2CCMDSTR=0x40;
}
static inline void i2c_clear_intflag(I2c_Reg *reg)
{
    while(i2c_flag_get(reg,TIP)); 
    reg->I2CCMDSTR=0x01;
}

#endif 