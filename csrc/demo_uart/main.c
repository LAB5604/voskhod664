#include "REG_SALYUT1.h"
#include "uart16550_driver.h"

int main() {
    int a = 78;
    uartinit();
    uart0_prints("Hello riscv!\r\n");
    uart0_prints("%d",a);
}