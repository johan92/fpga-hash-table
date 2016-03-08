//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

import hash_table::*;

interface ht_res_if( 
  input clk 
);

ht_result_t                 result;
logic                       valid;
logic                       ready;

modport master(
  output result,
  output valid,
  input  ready
);

modport slave(
  input  result,
  input  valid,
  output ready
);


// synthesis translate_off

logic accepted;

assign accepted = valid && ready;

clocking cb @( posedge clk );
  input result,
        accepted;
endclocking

// synthesis translate_on

endinterface
