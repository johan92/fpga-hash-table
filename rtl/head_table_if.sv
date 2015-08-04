interface head_table_if #(
  parameter A_WIDTH        = 8,
  parameter HEAD_PTR_WIDTH = 10
)(
  input clk_i
);

logic [BUCKET_WIDTH-1:0]   wr_addr;
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
