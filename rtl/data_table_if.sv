//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

import hash_table::*;

interface data_table_if #(
  parameter A_WIDTH = TABLE_ADDR_WIDTH
)(
  input clk
);

logic [A_WIDTH-1:0] rd_addr;
ram_data_t          rd_data;
logic               rd_en;

logic [A_WIDTH-1:0] wr_addr;
ram_data_t          wr_data; 
logic               wr_en;

modport master(
  input  rd_data,
  output rd_addr,
         rd_en,

         wr_addr,
         wr_data,
         wr_en

);

modport slave(
  output rd_data,
  input  rd_addr,
         rd_en,

         wr_addr,
         wr_data,
         wr_en

);

// synthesis translate_off
clocking cb @( posedge clk );

  input wr_addr,
        wr_data,
        wr_en,

        rd_addr,
        rd_en;

endclocking
// synthesis translate_on

endinterface
