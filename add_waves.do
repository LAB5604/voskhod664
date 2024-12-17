#------------------------------------------------------------------
#             add waves
#------------------------------------------------------------------
add wave -color yellow -divider {CPU Cache Access & Control}
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/icache_mif/*
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/icache_sif/*
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/dcache_mif/*
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/dcache_sif/*
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/icache_flush_req
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/icache_flush_ack
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/dcache_flush_req
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/dcache_flush_ack
add wave -radix hex fullsoc_tb/dut/prv664_core/pipline/burnaccess

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
#------------------------------------------------------------------
#       cpu bus
#------------------------------------------------------------------
add wave -color reg -divider {Bus signal}

add wave -color yellow -divider {CPU axi bus}
add wave -radix hex fullsoc_tb/dut/cpu_ibus_axi_ar/*
add wave -radix hex fullsoc_tb/dut/cpu_ibus_axi_r/*
add wave -radix hex fullsoc_tb/dut/cpu_dbus_axi_aw/*
add wave -radix hex fullsoc_tb/dut/cpu_dbus_axi_ar/*
add wave -radix hex fullsoc_tb/dut/cpu_dbus_axi_w/*
add wave -radix hex fullsoc_tb/dut/cpu_dbus_axi_b/*
add wave -radix hex fullsoc_tb/dut/cpu_dbus_axi_r/*
#-------------------------------------------------------------------
#           add soc waves
#-------------------------------------------------------------------
add wave -color yellow -divider {OCRAM axi bus}
add wave -radix hex fullsoc_tb/dut/ocram_axi_aw/*
add wave -radix hex fullsoc_tb/dut/ocram_axi_ar/*
add wave -radix hex fullsoc_tb/dut/ocram_axi_w/*
add wave -radix hex fullsoc_tb/dut/ocram_axi_b/*
add wave -radix hex fullsoc_tb/dut/ocram_axi_r/*

add wave -divider {XLIC axi bus}
add wave -radix hex fullsoc_tb/dut/axilcluster0_axi_aw/*
add wave -radix hex fullsoc_tb/dut/axilcluster0_axi_ar/*
add wave -radix hex fullsoc_tb/dut/axilcluster0_axi_w/*
add wave -radix hex fullsoc_tb/dut/axilcluster0_axi_b/*
add wave -radix hex fullsoc_tb/dut/axilcluster0_axi_r/*

add wave -divider {32bit axi-l bus}
add wave -radix hex fullsoc_tb/dut/axil32cluster0_axil_*
add wave -radix hex fullsoc_tb/dut/axil32cluster0_axil_*
add wave -radix hex fullsoc_tb/dut/axil32cluster0_axil_*
add wave -radix hex fullsoc_tb/dut/axil32cluster0_axil_*
add wave -radix hex fullsoc_tb/dut/axil32cluster0_axil_*