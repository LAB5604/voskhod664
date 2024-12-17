
/*
 * Anlogic Softcore SPI
 * For Anlogic Softcore BSP
 * Engineer: Xiaoyu HONG
 */

#ifndef SPI_H_
#define SPI_H_

#include <stdint.h>


typedef struct
{
  volatile uint32_t SPI_CTRL;
  volatile uint32_t SPI_BUF;
  volatile uint32_t SPI_STAT;
  volatile uint32_t SPI_DEVSEL;
} Spi_Reg;

static void Spi_init(Spi_Reg *reg,uint32_t cfg)
{
	reg->SPI_CTRL  =  cfg ;
	//reg->VALUE = 0;
}
static void Spi_devsel(Spi_Reg *reg,uint32_t sel)
{
  while(reg->SPI_STAT&0x03!=0x03);//Wait all TRx completely finish
  reg->SPI_DEVSEL=sel;
}
static uint32_t Spi_Getdevsel(Spi_Reg *reg)
{
  return reg->SPI_DEVSEL;
}
static void Spi_sendbyte(Spi_Reg *reg,uint8_t data)
{
  while((reg->SPI_STAT&0x02)==0);//Wait Tx completely finish
  reg->SPI_BUF=data;
}
static void Spi_sendstr(Spi_Reg *reg,uint8_t *data,uint32_t length)
{
  uint32_t i;
  for (i=0;i<length;i++)Spi_sendbyte(reg,data[i]);//reg->SPI_BUF=data[i]
}
static uint8_t Spi_recvbyte(Spi_Reg *reg)
{
  while((reg->SPI_STAT&0x01)==0);//Wait Tx Buf
  return reg->SPI_BUF;
}

#endif 