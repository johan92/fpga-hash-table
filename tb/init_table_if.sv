//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

interface init_table_if(
  input clk
);

// flag, shows, that we now in table initing...
logic in_init;

clocking cb @( posedge clk );
  
  input in_init;

endclocking

endinterface
