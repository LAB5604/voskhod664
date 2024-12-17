# quit simulation
quit -sim

# clean main window
.main clear 

vlib work
vmap work work

# set include file

#-----------------------------------------------------------------
#              complie source file 
#-----------------------------------------------------------------
vlog +incdir+./src ./src/*.v 
vlog +incdir+./src ./src/*.sv 
#vlog -work work ./src/*.v 
#vlog -work work ./src/*.sv

#------------------------------------------------------------------
#              start simulation
#------------------------------------------------------------------
vsim -novopt work.fullsoc_tb

#------------------------------------------------------------------
#             add waves
#------------------------------------------------------------------
add wave -color yellow -divider {CPU Cache Access & Control}
add wave -radix hex fullsoc_tb/dut/prv664_core/icache_access/*
add wave -radix hex fullsoc_tb/dut/prv664_core/icache_return/*
add wave -radix hex fullsoc_tb/dut/prv664_core/dcache_access/*
add wave -radix hex fullsoc_tb/dut/prv664_core/dcache_return/*
add wave -radix hex fullsoc_tb/dut/prv664_core/icache_flush_req
add wave -radix hex fullsoc_tb/dut/prv664_core/icache_flush_ack
add wave -radix hex fullsoc_tb/dut/prv664_core/dcache_flush_req
add wave -radix hex fullsoc_tb/dut/prv664_core/dcache_flush_ack

add wave -color yellow -divider {CPU IFU to IDU}
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/pip_ifu2decode/*

add wave -color yellow -divider {CPU IDU to DPU}
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/pip_decode2dispatch0/*
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/pip_decode2dispatch1/*

add wave -color yellow -divider {CPU IDU to ROB}
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/pip_decode2rob0/*
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/pip_decode2rob1/*

add wave -color yellow -divider {CPU writeback to ROB}
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/pip_wb2rob0/*
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/pip_wb2rob1/*

add wave -color yellow -divider {CPU commit0}
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/flush_commit/*
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/instr_commit0/*
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/int_commit0/*
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/fp_commit/*
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/csr_commit/*
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/bpu_commit/*

add wave -color yellow -divider {CPU commit1}
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/instr_commit1/*
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/int_commit1/*

add wave -color reg -divider {Bus signal}

add wave -color yellow -divider {CPU axi bus}
add wave -radix hex fullsoc_tb/dut/cpu_ibus_axi_ar/*
add wave -radix hex fullsoc_tb/dut/cpu_ibus_axi_r/*
add wave -radix hex fullsoc_tb/dut/cpu_dbus_axi_aw/*
add wave -radix hex fullsoc_tb/dut/cpu_dbus_axi_ar/*
add wave -radix hex fullsoc_tb/dut/cpu_dbus_axi_w/*
add wave -radix hex fullsoc_tb/dut/cpu_dbus_axi_b/*
add wave -radix hex fullsoc_tb/dut/cpu_dbus_axi_r/*
add wave -radix hex fullsoc_tb/dut/cpu_immu_axi_ar/*
add wave -radix hex fullsoc_tb/dut/cpu_immu_axi_r/*
add wave -radix hex fullsoc_tb/dut/cpu_dmmu_axi_ar/*
add wave -radix hex fullsoc_tb/dut/cpu_dmmu_axi_r/*

add wave -color yellow -divider {OCRAM axi bus}
add wave -radix hex fullsoc_tb/dut/ocram_axi_aw/*
add wave -radix hex fullsoc_tb/dut/ocram_axi_ar/*
add wave -radix hex fullsoc_tb/dut/ocram_axi_w/*
add wave -radix hex fullsoc_tb/dut/ocram_axi_b/*
add wave -radix hex fullsoc_tb/dut/ocram_axi_r/*

#-----------------------------------------------------------------
#                   Set simulation binary file 
#------------------------------------------------------------------
file copy -force bin/addi-riscv64-mycpu.txt hex.txt
echo "addi-riscv64 test begin"
#------------------------------------------------------------------
#             run simulations
#------------------------------------------------------------------
run -all

echo "==============addi-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   addiw test
#------------------------------------------------------------------
file copy -force bin/addiw-riscv64-mycpu.txt hex.txt
echo "addiw-riscv64 test begin"
restart -f
run -all
echo "==============addiw-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   add test
#------------------------------------------------------------------
file copy -force bin/add-riscv64-mycpu.txt hex.txt
echo "add-riscv64 test begin"
restart -f
run -all
echo "==============add-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   addw test
#------------------------------------------------------------------
file copy -force bin/addw-riscv64-mycpu.txt hex.txt
echo "addw-riscv64 test begin"
restart -f
run -all
echo "==============addw-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   andi test
#------------------------------------------------------------------
file copy -force bin/andi-riscv64-mycpu.txt hex.txt
echo "andi-riscv64 test begin"
restart -f
run -all
echo "==============andi-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   and test
#------------------------------------------------------------------
file copy -force bin/and-riscv64-mycpu.txt hex.txt
echo "and-riscv64 test begin"
restart -f
run -all
echo "==============and-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   auipc test
#------------------------------------------------------------------
file copy -force bin/auipc-riscv64-mycpu.txt hex.txt
echo "auipc-riscv64 test begin"
restart -f
run -all
echo "==============auipc-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   beq test
#------------------------------------------------------------------
file copy -force bin/beq-riscv64-mycpu.txt hex.txt
echo "beq-riscv64 test begin"
restart -f
run -all
echo "==============beq-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   bge test
#------------------------------------------------------------------
file copy -force bin/bge-riscv64-mycpu.txt hex.txt
echo "bge-riscv64 test begin"
restart -f
run -all
echo "==============bge-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   bgeu test
#------------------------------------------------------------------
file copy -force bin/bgeu-riscv64-mycpu.txt hex.txt
echo "bgeu-riscv64 test begin"
restart -f
run -all
echo "==============bgeu-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   blt test
#------------------------------------------------------------------
file copy -force bin/blt-riscv64-mycpu.txt hex.txt
echo "blt-riscv64 test begin"
restart -f
run -all
echo "==============blt-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   bltu test
#------------------------------------------------------------------
file copy -force bin/bltu-riscv64-mycpu.txt hex.txt
echo "bltu-riscv64 test begin"
restart -f
run -all
echo "==============bltu-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   bne test
#------------------------------------------------------------------
file copy -force bin/bne-riscv64-mycpu.txt hex.txt
echo "bne-riscv64 test begin"
restart -f
run -all
echo "==============bne-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   jal test
#------------------------------------------------------------------
file copy -force bin/jal-riscv64-mycpu.txt hex.txt
echo "jal-riscv64 test begin"
restart -f
run -all
echo "==============jal-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   jalr test
#------------------------------------------------------------------
file copy -force bin/jalr-riscv64-mycpu.txt hex.txt
echo "jalr-riscv64 test begin"
restart -f
run -all
echo "==============jalr-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   lb test
#------------------------------------------------------------------
file copy -force bin/lb-riscv64-mycpu.txt hex.txt
echo "lb-riscv64 test begin"
restart -f
run -all
echo "==============lb-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   lbu test
#------------------------------------------------------------------
file copy -force bin/lbu-riscv64-mycpu.txt hex.txt
echo "lbu-riscv64 test begin"
restart -f
run -all
echo "==============lbu-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   lh test
#------------------------------------------------------------------
file copy -force bin/lh-riscv64-mycpu.txt hex.txt
echo "lh-riscv64 test begin"
restart -f
run -all
echo "==============lh-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   lhu test
#------------------------------------------------------------------
file copy -force bin/lhu-riscv64-mycpu.txt hex.txt
echo "lhu-riscv64 test begin"
restart -f
run -all
echo "==============lhu-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   lw test
#------------------------------------------------------------------
file copy -force bin/lw-riscv64-mycpu.txt hex.txt
echo "lw-riscv64 test begin"
restart -f
run -all
echo "==============lw-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   lwu test
#------------------------------------------------------------------
file copy -force bin/lwu-riscv64-mycpu.txt hex.txt
echo "lwu-riscv64 test begin"
restart -f
run -all
echo "==============lwu-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   ld test
#------------------------------------------------------------------
file copy -force bin/ld-riscv64-mycpu.txt hex.txt
echo "ld-riscv64 test begin"
restart -f
run -all
echo "==============ld-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   ori test
#------------------------------------------------------------------
file copy -force bin/ori-riscv64-mycpu.txt hex.txt
echo "ori-riscv64 test begin"
restart -f
run -all
echo "==============ori-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   or test
#------------------------------------------------------------------
file copy -force bin/or-riscv64-mycpu.txt hex.txt
echo "or-riscv64 test begin"
restart -f
run -all
echo "==============or-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   sb test
#------------------------------------------------------------------
file copy -force bin/sb-riscv64-mycpu.txt hex.txt
echo "sb-riscv64 test begin"
restart -f
run -all
echo "==============sb-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   sh test
#------------------------------------------------------------------
file copy -force bin/sh-riscv64-mycpu.txt hex.txt
echo "sh-riscv64 test begin"
restart -f
run -all
echo "==============sh-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   sw test
#------------------------------------------------------------------
file copy -force bin/sw-riscv64-mycpu.txt hex.txt
echo "sw-riscv64 test begin"
restart -f
run -all
echo "==============sw-riscv64 test PASS=============="
#------------------------------------------------------------------
#                   sd test
#------------------------------------------------------------------
file copy -force bin/sd-riscv64-mycpu.txt hex.txt
echo "sd-riscv64 test begin"
restart -f
run -all
echo "==============sd-riscv64 test PASS=============="

echo "========most rv64i instructions test pass======="