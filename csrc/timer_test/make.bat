set GCC_PATH=E:\APP\RISCV_GCC\gcc\bin\
set BIN2MEM=..\..\BinToMem_CLI.py
::complie
%GCC_PATH%riscv-nuclei-elf-gcc -nostdlib -march=rv64i -mcmodel=medany timer.s -o timer.exec -T ../link.lds -Wall
%GCC_PATH%riscv-nuclei-elf-objdump --disassemble-all timer.exec > timer_dump.txt
%GCC_PATH%riscv-nuclei-elf-objdump --disassemble-all timer.exec
%GCC_PATH%riscv-nuclei-elf-objcopy -O binary timer.exec timer.bin
::generate 8bit and 64bit file for fpga use
python %BIN2MEM% timer.bin timer8.txt 8
python %BIN2MEM% timer.bin timer64.txt 64