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
#vlog +incdir+./src ./src/*.v 
#vlog +define+INIT_FILE=uart_demo64.txt +incdir+./src ./src/*.sv 
vlog -work work +incdir+../src/include +define+INIT_FILE="../bin/main.bin" ../src/*.v 
vlog -work work +incdir+../src/include +define+INIT_FILE="../bin/main.bin" ../src/*.sv
#                                      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                                      change this to other init file

#------------------------------------------------------------------
#              start simulation
#------------------------------------------------------------------
vsim -novopt work.fullsoc_tb

#------------------------------------------------------------------
#               add waves of simulation
#------------------------------------------------------------------
do add_waves.do
#-----------------------------------------------------------------
#                   Set simulation binary file 
#------------------------------------------------------------------
#file copy -force bin/startup8.txt hex.txt

#------------------------------------------------------------------
#             run simulations
#------------------------------------------------------------------
run -all
