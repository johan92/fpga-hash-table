//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

import hash_table::*;

interface head_table_if #(
  parameter A_WIDTH = BUCKET_WIDTH
)(
  input clk
);

logic [A_WIDTH-1:0]        wr_addr;
head_ram_data_t            wr_data;
logic                      wr_en;

modport master(
  output wr_addr,
         wr_data,
         wr_en
);

modport slave(
  input  wr_addr,
         wr_data,
         wr_en
);

// synthesis translate_off
clocking cb @( posedge clk );

  input wr_addr,
        wr_data,
        wr_en;

endclocking
// synthesis translate_on

endinterface
