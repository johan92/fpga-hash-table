//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

import hash_table::*;

module head_table_if_mux #(
  parameter DIR_CNT = 4
) (

  head_table_if.slave     in_if   [DIR_CNT-1:0],
  head_table_if.master    out_if

);
localparam A_WIDTH   = BUCKET_WIDTH;
localparam DIR_CNT_W = $clog2( DIR_CNT );

logic [A_WIDTH-1:0] wr_addr [DIR_CNT-1:0];
head_ram_data_t     wr_data [DIR_CNT-1:0];
logic               wr_en   [DIR_CNT-1:0];

genvar g;
generate
  for( g = 0; g < DIR_CNT; g++ )
    begin
      assign wr_addr [g] = in_if[g].wr_addr; 
      assign wr_data [g] = in_if[g].wr_data; 
      assign wr_en   [g] = in_if[g].wr_en;   
    end
endgenerate

logic [DIR_CNT_W-1:0] wr_sel;

always_comb
  begin
    wr_sel = '0;

    for( int i = 0; i < DIR_CNT; i++ )
      begin
        if( wr_en[i] )
          wr_sel = i[DIR_CNT_W-1:0];
      end
  end

assign out_if.wr_addr = wr_addr [ wr_sel ];
assign out_if.wr_data = wr_data [ wr_sel ];
assign out_if.wr_en   = wr_en   [ wr_sel ];


endmodule
