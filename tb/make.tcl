proc do_compile {} {
  exec rm -rf work/
  vlib work

  # compiling files
  vlog -work work -coverall "../rtl/hash_table_pkg.sv"
  vlog -work work -coverall "../tb/ht_tb_pkg.sv"
  vlog -work work -coverall "../tb/ht_res_monitor.sv"
  vlog -work work -coverall "../tb/tables_monitor.sv"
  vlog -work work -coverall "top_tb.sv"
  vlog -work work -coverall "../rtl/*.sv" 
  vlog -work work -coverall "../rtl/*.v"
}

proc start_sim {} {
  # insert name of testbench module
  vsim -coverage -novopt top_tb 

  # adding all waveforms in hex view
  add wave -r -hex *

  # running simulation for some time
  # you can change for run -all for infinity simulation :-)
  run -all 
  #run 100us
}


proc show_coverage {} {
  coverage save 1.ucdb
  vcover report 1.ucdb -verbose -cvg
}

proc run_test {} {
  do_compile
  start_sim
}

proc help {} {
  echo "help                - show this message"
  echo "do_compile          - compile all"
  echo "start_sim           - start simulation"
  echo "run_test            - do_compile & start_sim"
  echo "show_coverage       - show coverage report"
}

help
