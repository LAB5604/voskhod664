#ifndef SD_SPI_H_
#define SD_SPI_H_

#include <stdint.h>
#include "maxcore.h"
#include "spi.h"
#include "anl_printf.h"
//Device Config
#define SD_SPI SPI
#define SD_DEVMASK 0x01
#define SPI_CS_LOW  Spi_devsel(SD_SPI,(Spi_Getdevsel(SD_SPI)&(~(uint32_t)SD_DEVMASK)))
#define SPI_CS_HIGH Spi_devsel(SD_SPI,(Spi_Getdevsel(SD_SPI)|((uint32_t)SD_DEVMASK)))
//#define DEBUG_OUTPUT
//SD卡命令定�?                                                           
#define    CMD0  0x00        
#define    CMD1  0x01
#define    CMD8  0x08
#define    CMD9  0x09
#define    CMD10 0x0A
#define    CMD11 0x0B
#define    CMD12 0x0C
#define    CMD16 0x10
#define    CMD17 0x11
#define    CMD24 0x18
           
#define    CMD41 0x29
#define    CMD55 0x37
#define    CMD58 0x3A
#define    CMD59 0x3B


// SD卡类型定�?               
#define SD_TYPE_ERR     0X00  
#define MMC             0X01  
#define V1              0X02  
#define V2              0X04  
#define V2HC            0X06  

uint8_t SD_Type;

void SD_SPI_WriteByte(uint8_t byte);
uint8_t SD_SPI_ReadByte();
uint8_t SD_Select(void);
void SD_DisSelect(void);
uint8_t SD_SendCmd(uint8_t cmd, uint32_t arg, uint8_t crc, uint8_t reset);
uint8_t Sdcard_init();
uint8_t SD_GetResponse(uint8_t response);
uint8_t SdRecvData(uint8_t *buf,uint16_t len);
uint8_t SDReadSector(uint8_t *buf,uint32_t sector);
uint8_t SD_SendBlock(uint8_t*buf,uint8_t cmd);
uint8_t SDWriteSector(uint8_t *buf,uint32_t sector) ;
#endif 