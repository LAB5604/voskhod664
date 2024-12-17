#include <stdint.h>

int vga_char_print(int position, uint8_t *string, int length);

int vga_chmem_set(int position, uint8_t c, int length);

int vga_comem_set(int position, uint8_t c, int length);