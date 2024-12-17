/*simple link for salyut1 soc*/

OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS
{
  . = 0x80000000;
  .text : { *(.text) }
  .data { *(.data) }
  .rodata {*(.rodata)}
  .bss : { *(.bss) }
  _end = .;
}