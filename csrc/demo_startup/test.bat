set GCC_PATH=G:\project\RVGCC\gcc\bin\
set BIN2MEM=..\..\BinToMem_CLI.py
::complie
%GCC_PATH%riscv-nuclei-elf-gcc -nostdlib -march=rv64i -mcmodel=medany startup.s -o startup.exec -T ../link.lds -Wall
%GCC_PATH%riscv-nuclei-elf-objdump --disassemble-all startup.exec > startup_dump.txt
%GCC_PATH%riscv-nuclei-elf-objdump --disassemble-all startup.exec
%GCC_PATH%riscv-nuclei-elf-objcopy -O binary startup.exec startup.bin
::generate 8bit and 64bit file for fpga use
python %BIN2MEM% startup.bin startup8.txt 8
python %BIN2MEM% startup.bin startup64.txt 64