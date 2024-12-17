#include <stdint.h>
#include "../include/REG_SALYUT1.h"

/**********************************************************************
vga char display
    call args:  uint32_t position    position of first char to display (0~2039)
                uint8_t *string      string
                uint32_t length      length want to display(0~2039) 
                         NOTE： position + length <= 2400
    return:     0 success display
                1 display out of range
                2~6 reserved
                7 hardware problem
***********************************************************************/
int vga_char_print(int position, char *string, int length){
    //int src_pointer, dest_pointer;
    uint8_t *psrc, *pdest;
    pdest = VGA_TXT_BASE;
    psrc = string;
    int i;
    if((position + length)>2400){   //可显示范围一共不超过2400字节，超过就不显示
        return 1;
    } else {
        for(i=0; i<length; i=i+1){
            *pdest = *psrc;
            psrc = psrc + 1;
            pdest= pdest + 1;
            //ACCESS_BYTE(dest_pointer) = ACCESS_BYTE(src_pointer);
            //dest_pointer = dest_pointer + 1;
            //src_pointer = src_pointer + 1;
        }
        return 0;
    } 
}
/**********************************************************************
vga char memory set
    call args:  uint32_t position    position of first char to display (0~2039)
                uint32_t length      length want to display(0~2039) 
                         NOTE： position + length <= 2400
    return:     0 success display
                1 display out of range
                2~6 reserved
                7 hardware problem
***********************************************************************/
int vga_chmem_set(int position, char c, int length){
    uint8_t *pdest;
    pdest = VGA_TXT_BASE + position;
    int i;
    if((position + length)>2400){   //可显示范围一共不超过2400字节，超过就不显示
        return 1;
    } else {
        for(i=0; i<length; i=i+1){
            *pdest = c;
            pdest= pdest + 1;
        }
        return 0;
    } 
}
/**********************************************************************
vga color memory set
    call args:  uint32_t position    position of first char to display (0~2039)
                uint32_t length      length want to display(0~2039) 
                         NOTE： position + length <= 2400
    return:     0 success display
                1 display out of range
                2~6 reserved
                7 hardware problem
***********************************************************************/
int vga_comem_set(int position, uint8_t c, int length){
    uint8_t *pdest;
    int i;
    pdest = VGA_TXT_BASE + position;
    if((position + length)>2400){   //可显示范围一共不超过2400字节，超过就不显示
        return 1;
    } else {
        for(i=0; i<length; i=i+1){
            *pdest = c;
            pdest= pdest + 1;
        }
        return 0;
    } 
}