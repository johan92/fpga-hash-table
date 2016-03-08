//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

import hash_table::*;

interface empty_ptr_storage_if #(
  parameter A_WIDTH = hash_table::TABLE_ADDR_WIDTH 
)( 
  input clk 
);

logic                srst;

// interface to add empty pointers
logic  [A_WIDTH-1:0] add_empty_ptr;
logic                add_empty_ptr_en;

// interface to read empty pointers,
// if val is zero - there is no more empty pointers
logic                next_empty_ptr_rd_ack;
logic [A_WIDTH-1:0]  next_empty_ptr;
logic                next_empty_ptr_val;

modport master(
  output srst,

  output add_empty_ptr,
         add_empty_ptr_en,

  output next_empty_ptr_rd_ack,
  input  next_empty_ptr,
         next_empty_ptr_val

);

modport slave(
  input  srst,

  input  add_empty_ptr,
         add_empty_ptr_en,

  input  next_empty_ptr_rd_ack,
  output next_empty_ptr,
         next_empty_ptr_val

);

// synthesis translate_off

clocking cb @( posedge clk );
  input  srst,

         add_empty_ptr,
         add_empty_ptr_en,

         next_empty_ptr_rd_ack,
         next_empty_ptr,
         next_empty_ptr_val;

endclocking

// synthesis translate_on

endinterface
