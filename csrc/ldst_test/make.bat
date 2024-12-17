::set path
set GCC_PATH=E:\APP\RISCV_GCC\gcc\bin\
set BIN2MEM=..\..\BinToMem_CLI.py

set C_FLAG=-nostdlib -march=rv64i -mabi=lp64 -mcmodel=medany -O0
set INCLUDE= 
set ASM_SRC= main.s
set C_SRC= 
set LINK_OBJ= 
set LDFLAG= -T ../link.lds -nostartfiles -Wl,--gc-sections -Wl,--check-sections
::complie
%GCC_PATH%riscv-nuclei-elf-gcc %C_FLAG% %ASM_SRC% %C_SRC% %LINK_OBJ% -o main.exec %LDFLAG%
%GCC_PATH%riscv-nuclei-elf-objdump --disassemble-all main.exec > main_dump.txt
%GCC_PATH%riscv-nuclei-elf-objdump --disassemble-all main.exec
%GCC_PATH%riscv-nuclei-elf-objcopy -O binary main.exec main.bin
::generate 8bit and 64bit file for fpga use
python %BIN2MEM% main.bin main8.txt 8
python %BIN2MEM% main.bin main64.txt 64