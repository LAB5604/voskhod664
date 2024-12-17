#ifndef DELAY_H_
#define DELAY_H_
#include <stdint.h>

void Delay(int cycle)
{
    int i;
    volatile uint32_t *pa;
    pa=0xFFFFFFF0;
    for (i=0;i<cycle;i++)
        *pa=i;
}


#endif
