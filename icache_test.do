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
vsim -novopt work.icache_difftest

#------------------------------------------------------------------
#             add waves
#------------------------------------------------------------------
add wave -radix hex icache_difftest/dut/*
#------------------------------------------------------------------
#             run simulations
#------------------------------------------------------------------
run -all