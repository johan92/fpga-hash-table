rm -rf work/
vlib work

# compiling files
vlog ../rtl/hash_table_pkg.sv 
vlog top_tb.sv 
vlog ../rtl/*.sv 
vlog ../rtl/*.v 

# insert name of testbench module
vsim -novopt top_tb

# adding all waveforms in hex view
 add wave -r -hex *
#add wave -r -hex sim://top_tb/dut/data_table/*

# running simulation for some time
# you can change for run -all for infinity simulation :-)
run 2000ns
