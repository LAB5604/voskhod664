#define VGA_TXT_BASE    0x00008000
#define VGA_COLOR_BASE  0x00009000
#define VGA_BLINK_BASE  0x0000A000
#define VGA_COL_NUM     80
#define VGA_ROW_NUM     30
//Timer
#define CSR_MTIME       0x40000000
#define CSR_MTIMECMP    0x40000008
//UART
#define UART0_RB        (*(volatile unsigned int *)0x00000000)
#define UART0_THR       (*(volatile unsigned int *)0x00000000)
#define UART0_DLL       (*(volatile unsigned int *)0x00000000)
#define UART0_DLM       (*(volatile unsigned int *)0x00000004)
#define UART0_IE        (*(volatile unsigned int *)0x00000004)
#define UART0_II        (*(volatile unsigned int *)0x00000008)
#define UART0_FIFOC     (*(volatile unsigned int *)0x00000008)
#define UART0_LCR       (*(volatile unsigned int *)0x0000000C)
#define UART0_MC        (*(volatile unsigned int *)0x00000010)
#define UART0_LS        (*(volatile unsigned int *)0x00000014)
#define UART0_MS        (*(volatile unsigned int *)0x00000018)


//8bit access instruction must be use in legucy 8bit IO space
#define ACCESS_BYTE(addr) (*((volatile char *)(addr)))
