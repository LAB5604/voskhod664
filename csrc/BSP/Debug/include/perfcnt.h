/*
 * Anlogic Softcore debug facility
 * Performance Counter Functions 
 * For Anlogic Softcore BSP
 * Engineer: Xiaoyu HONG
 */
//Attention, Bus Performance Counter needs to be enabled first!!! 

#ifndef PERFCNT_H_
#define PERFCNT_H_
#include <stdint.h>
#define IBUS_FETCHCNT   *((volatile uint32_t*)(CLSIC_BASE+0x1000))
#define IBUS_CYCLECNT   *((volatile uint32_t*)(CLSIC_BASE+0x1004))
#define DBUS_MEFETCNT   *((volatile uint32_t*)(CLSIC_BASE+0x1008))
#define DBUS_PEFETCNT   *((volatile uint32_t*)(CLSIC_BASE+0x100C))
#define DBUS_MECYCCNT   *((volatile uint32_t*)(CLSIC_BASE+0x1010))
#define DBUS_PECYCCNT   *((volatile uint32_t*)(CLSIC_BASE+0x1014))

void ClrPerfCnt()
{
    IBUS_FETCHCNT=0;
    IBUS_CYCLECNT=0;
    DBUS_MEFETCNT=0;
    DBUS_MECYCCNT=0;
    DBUS_PEFETCNT=0;
    DBUS_PECYCCNT=0;
}

void DumpPerfCnt(uint32_t *buffer)
{
    buffer[0]=IBUS_FETCHCNT;
    buffer[1]=IBUS_CYCLECNT;
    buffer[2]=DBUS_MEFETCNT;
    buffer[3]=DBUS_MECYCCNT;
    buffer[4]=DBUS_PEFETCNT;
    buffer[5]=DBUS_PECYCCNT;
}
#ifdef _ANL_PRINTF_H
void RptPerfCnt()
{
    anl_printf("Total IBus Fetch Count:%x \r\n" ,IBUS_FETCHCNT);
    anl_printf("Total IBus Access Cycle Count:%x \r\n" ,IBUS_CYCLECNT);
    
    anl_printf("Total DBus Memory Fetch Count:%x \r\n" ,DBUS_MEFETCNT);
    anl_printf("Total DBus Memory Access Cycle Count:%x \r\n" ,DBUS_MECYCCNT);

    anl_printf("Total DBus Peripheral Fetch Count:%x \r\n" ,DBUS_PEFETCNT);
    anl_printf("Total DBus Peripheral Access Cycle Count:%x \r\n" ,DBUS_PECYCCNT);
}
#endif
#endif
