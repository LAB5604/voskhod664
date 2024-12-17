#include "REG_SALYUT1.h"

void uartinit() {
    // disable interrupt
    UART0_IE = 0x00000000;
    // set baud rate
    UART0_LCR = 0x00000080;
    UART0_DLL = 0x00000003;  //FIXME: uart波特率设置不能写死
    UART0_DLM = 0x00000000;
    // set word length to 8-bits
    UART0_LCR = 0x00000003;
    // enable FIFOs
    UART0_FIFOC = 0x00000007;
    // enable receiver interrupts
    UART0_IE = 0x00000001;
}

void uartputc(char c) { //发送一个字符
    while(UART0_LS & (1 << 5) == 0) { ;}        //如果发送fifo没有空，则持续等待
    UART0_THR = c;
}

void uart0_prints(char *puts) //发送一个字符串
{
    for (; *puts != 0;  puts++) uartputc(*puts);    //遇到停止符0结束
}