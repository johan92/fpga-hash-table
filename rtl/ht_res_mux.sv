//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

import hash_table::*;

module ht_res_mux #(
  parameter DIR_CNT = 3
) (

  ht_res_if.slave      ht_res_in [DIR_CNT-1:0],
  ht_res_if.master     ht_res_out

);

localparam DIR_CNT_WIDTH = $clog2( DIR_CNT );

ht_result_t               result        [DIR_CNT-1:0];
logic                     result_valid  [DIR_CNT-1:0]; 
logic                     result_ready  [DIR_CNT-1:0];

ht_result_t               mux_result;
logic                     mux_result_valid; 

logic [DIR_CNT_WIDTH-1:0] sel;

genvar g;
generate
  for( g = 0; g < DIR_CNT; g++ )
    begin : conv_to_wires
      assign result[g]          = ht_res_in[g].result;
      assign result_valid[g]    = ht_res_in[g].valid;
      assign ht_res_in[g].ready = result_ready[g];
    end
endgenerate

always_comb
  begin
    sel = '0;
    for( int i = 0; i < DIR_CNT; i++ )
      begin
        // hope only one result_valid is valid
        if( result_valid[i] )
          sel = i[DIR_CNT_WIDTH-1:0];
      end
  end

assign mux_result        = result[ sel ];
assign mux_result_valid  = result_valid[ sel ];

always_comb
  begin
    for( int i = 0; i < DIR_CNT; i++ )
      begin
        result_ready[i] = !result_valid[i];
      end

    result_ready[ sel ] = ht_res_out.ready;
  end

assign ht_res_out.result = mux_result;    
assign ht_res_out.valid  = mux_result_valid; 

endmodule
