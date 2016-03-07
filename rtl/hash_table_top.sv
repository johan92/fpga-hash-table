//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

import hash_table::*;

module hash_table_top( 

  input                    clk_i,
  input                    rst_i,
  
  ht_cmd_if.slave          ht_cmd_in,
  ht_res_if.master         ht_res_out

);

head_table_if head_table_if(
  .clk            ( clk_i            )
);

ht_pdata_t  pdata_in;
logic       pdata_in_valid;
logic       pdata_in_ready;

ht_pdata_t  pdata_calc_hash; 
logic       pdata_calc_hash_valid;
logic       pdata_calc_hash_ready;

ht_pdata_t  pdata_head_table; 
logic       pdata_head_table_valid;
logic       pdata_head_table_ready;

always_comb
  begin
    pdata_in     = '0;

    pdata_in.cmd = ht_cmd_in.cmd;
  end

assign pdata_in_valid  = ht_cmd_in.valid;
assign ht_cmd_in.ready = pdata_in_ready;

calc_hash calc_hash (
  .clk_i                                  ( clk_i                 ),
  .rst_i                                  ( rst_i                 ),

  .pdata_in_i                             ( pdata_in              ),
  .pdata_in_valid_i                       ( pdata_in_valid        ),
  .pdata_in_ready_o                       ( pdata_in_ready        ),

  .pdata_out_o                            ( pdata_calc_hash       ),
  .pdata_out_valid_o                      ( pdata_calc_hash_valid ),
  .pdata_out_ready_i                      ( pdata_calc_hash_ready )
);

head_table h_tbl (
  .clk_i                                  ( clk_i                      ),
  .rst_i                                  ( rst_i                      ),

  .pdata_in_i                             ( pdata_calc_hash            ),
  .pdata_in_valid_i                       ( pdata_calc_hash_valid      ),
  .pdata_in_ready_o                       ( pdata_calc_hash_ready      ),

  .pdata_out_o                            ( pdata_head_table           ),
  .pdata_out_valid_o                      ( pdata_head_table_valid     ),
  .pdata_out_ready_i                      ( pdata_head_table_ready     ),
    
  .head_table_if                          ( head_table_if              )

);

data_table d_tbl (
  .clk_i                                  ( clk_i                   ),
  .rst_i                                  ( rst_i                   ),

  .pdata_in_i                             ( pdata_head_table        ),
  .pdata_in_valid_i                       ( pdata_head_table_valid  ),
  .pdata_in_ready_o                       ( pdata_head_table_ready  ),

  .ht_res_out                             ( ht_res_out              ),
    
  .head_table_if                          ( head_table_if           )

);

endmodule
