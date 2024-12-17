
#ifndef _ANL_PRINTF_H
#define _ANL_PRINTF_H
#include <stdint.h>
#ifdef __cplusplus
 extern "C" {
#endif

int anl_puts(char *s);

void anl_putchar(char c); 

static void printf_c(int c); 

static void printf_s(char *p);

static void printf_d(int val);

static void printf_x(unsigned int val);

static void printf_ld(int64_t val);

static void printf_lx(uint64_t val);

int anl_printf(const char *format, ...);
#define DEBUG_UART UART
#ifdef __cplusplus
}
#endif

#endif /* _ANL_PRINTF_H */

