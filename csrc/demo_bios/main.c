#include <stdint.h>
#include <REG_SALYUT1.h>

void *memset(void *s, int var, unsigned int num);
void *memcpy(void *str1, const void *str2, size_t n);

const char first_display[40] = "SALYUT1 VGA BIOS";

void main(){
    unit32_t vram_ptr = VGA_TXT_BASE;
    memset(vram_ptr, 0x00, 2400);       //字符显示区清零
    vram_ptr = VGA_COLOR_BASE;          
    memset(vram_ptr, 0xF0, 2400);       //前景色设置为白 背景设置为黑
    vram_ptr = VGA_TXT_BASE;
    memcopy(vram_ptr, first_display, 16);
    while(1){

    }
}
