//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

import hash_table::*;

module data_table_if_mux #(
  parameter DIR_CNT = 4
)(

  data_table_if.slave    dt_in_if   [DIR_CNT-1:0],
  data_table_if.master   dt_out_if

);

localparam DIR_CNT_W = $clog2( DIR_CNT );
localparam A_WIDTH   = hash_table::TABLE_ADDR_WIDTH;

// converting to wires
logic       [A_WIDTH-1:0] rd_addr  [DIR_CNT-1:0];
ram_data_t                rd_data  [DIR_CNT-1:0];
logic                     rd_en    [DIR_CNT-1:0];

logic       [A_WIDTH-1:0] wr_addr  [DIR_CNT-1:0];
ram_data_t                wr_data  [DIR_CNT-1:0];
logic                     wr_en    [DIR_CNT-1:0];

genvar g;
generate
  for( g = 0; g < DIR_CNT; g++ )
    begin : g_conv_to_wires
      assign dt_in_if[g].rd_data = rd_data[g];

      assign rd_addr  [g] = dt_in_if[g].rd_addr;
      assign rd_en    [g] = dt_in_if[g].rd_en;
                                               
      assign wr_addr  [g] = dt_in_if[g].wr_addr;
      assign wr_data  [g] = dt_in_if[g].wr_data;
      assign wr_en    [g] = dt_in_if[g].wr_en;

    end
endgenerate

logic [DIR_CNT_W-1:0] rd_sel;
logic [DIR_CNT_W-1:0] wr_sel;

always_comb
  begin
    rd_sel = '0;

    for( int i = 0; i < DIR_CNT; i++ )
      begin
        if( rd_en[i] )
          rd_sel = i[DIR_CNT_W-1:0];
      end
  end

always_comb
  begin
    wr_sel = '0;

    for( int i = 0; i < DIR_CNT; i++ )
      begin
        if( wr_en[i] )
          wr_sel = i[DIR_CNT_W-1:0];
      end
  end

generate
  for( g = 0; g < DIR_CNT; g++ )
    begin
      assign rd_data[g] = dt_out_if.rd_data;
    end
endgenerate

assign dt_out_if.rd_addr = rd_addr [ rd_sel ];
assign dt_out_if.rd_en   = rd_en   [ rd_sel ];

assign dt_out_if.wr_addr = wr_addr [ wr_sel ];
assign dt_out_if.wr_data = wr_data [ wr_sel ];
assign dt_out_if.wr_en   = wr_en   [ wr_sel ];  

endmodule
