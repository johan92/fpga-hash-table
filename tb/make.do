rm -rf work/
vlib work

# compiling files
vlog -coverall ../rtl/hash_table_pkg.sv
vlog -coverall ../tb/ht_tb_pkg.sv
vlog -coverall ../tb/ht_res_monitor.sv
vlog -coverall top_tb.sv 
vlog -coverall ../rtl/*.sv 
vlog -coverall ../rtl/*.v 

# insert name of testbench module
vsim -coverage -novopt top_tb 

# adding all waveforms in hex view
add wave -r -hex *
#add wave sim:/top_tb/dut/resm/ABC
add wave sim:/top_tb/dut/resm/bucket_occup

toggle add -r sim:/top_tb/dut/resm/*

#add wave -r -hex sim://top_tb/dut/data_table/*

# running simulation for some time
# you can change for run -all for infinity simulation :-)
run 10000ns

coverage save 1.ucdb

vcover report 1.ucdb -verbose -cvg
