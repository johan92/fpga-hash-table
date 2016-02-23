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
logic [HEAD_PTR_WIDTH-1:0] wr_data_ptr;
logic                      wr_data_ptr_val;
logic                      wr_en;

modport master(
  output wr_addr,
         wr_data_ptr,
         wr_data_ptr_val,
         wr_en
);

modport slave(
  input  wr_addr,
         wr_data_ptr,
         wr_data_ptr_val,
         wr_en
);

endinterface
