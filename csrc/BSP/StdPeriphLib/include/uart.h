/*
 * Anlogic Softcore UART
 * For Anlogic Softcore BSP
 * Engineer: Xiaoyu HONG
 */

#ifndef UART_H_
#define UART_H_
#include <stdint.h>

typedef struct
{
  volatile uint32_t DATA;
  volatile uint32_t STATUS;
  volatile uint32_t TRX_CONFIG;
} Uart_Reg;

enum UartParity {NONE = 0,EVEN = 2,ODD = 3};
enum UartStop {ONE = 0,ONEHALF = 2,TWO = 3};
enum Boolean {False = 0,True = 1};
typedef struct {
	enum Boolean IntEnable;
	enum Boolean Event_ParityCheckFail;
	enum Boolean Event_RxFifoHalfFull;
	enum Boolean Event_TxFifoHalfEmpty;
	enum Boolean Event_RxFinish;
	enum Boolean Event_TxFinish;
	enum Boolean RxFifoEnable;
	enum Boolean TxFifoEnable;
	enum UartParity Parity;
	enum Boolean Stop;
	uint32_t BaudDivider;
} Uart_Config;


static inline uint32_t uart_ChkWrBusy(Uart_Reg *reg)
{
	return ((reg->STATUS & 0x00000020)!=0);
}
static inline uint32_t uart_ReadValid(Uart_Reg *reg)
{
	return ((reg->STATUS & 0x00000040)!=0);
}
static inline void uart_ClrEvent(Uart_Reg *reg,uint8_t event)
{
	reg->STATUS=event;
	return;
}
static inline void uart_write(Uart_Reg *reg, uint8_t data)
{
	while(uart_ChkWrBusy(reg) == 0);
	reg->DATA = (uint32_t) data;
	return;
}

static inline uint8_t uart_read(Uart_Reg *reg)
{
	return reg->DATA;
}

static void uart_applyConfig(Uart_Reg *reg, Uart_Config *config)
{
	uint32_t reg_config=0;

	reg_config = (config->BaudDivider & 0x00003FFF)
	| ((config->Stop & 0x03)<<14)
	| ((config->Parity & 0x03)<<16)
	| ((config->TxFifoEnable & 0x01)<<18)
	| ((config->RxFifoEnable & 0x01)<<19)
	| ((config->Event_TxFinish & 0x01)<<24)
	| ((config->Event_RxFinish & 0x01)<<25)
	| ((config->Event_TxFifoHalfEmpty & 0x01)<<26)
	| ((config->Event_RxFifoHalfFull & 0x01)<<27)
	| ((config->Event_ParityCheckFail & 0x01)<<28)
	| ((config->IntEnable & 0x01)<<31);
	reg->TRX_CONFIG = reg_config;
	return;
}
static void print(const char*str,Uart_Reg *reg)
{
	while(*str){
		uart_write(reg,*str);
		str++;
	}
	return;
}
#endif /* UART_H_ */


