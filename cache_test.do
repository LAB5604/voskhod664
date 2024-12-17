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

vlog -work work +incdir+../src/include ../src/*.v 
vlog -work work +incdir+../src/include ../src/*.sv

#------------------------------------------------------------------
#              start simulation
#------------------------------------------------------------------
vsim -novopt work.cache_difftest

#------------------------------------------------------------------
#               add waves of simulation
#------------------------------------------------------------------
add wave -radix hex cache_difftest/dut/*

#------------------------------------------------------------------
#             run simulations
#------------------------------------------------------------------
run -all