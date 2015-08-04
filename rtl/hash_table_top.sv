import hash_table::*;

module hash_table_top #( 
  parameter KEY_WIDTH        = 32,
  parameter VALUE_WIDTH      = 16,
  parameter BUCKET_WIDTH     = 8,
  parameter HASH_TYPE        = "dummy"
  parameter TABLE_ADDR_WIDTH = 10
)(

  input                    clk_i,
  input                    rst_i,
  
  ht_if.slave              ht_in,

  output [KEY_WIDTH-1:0]   key_o,
  output [VALUE_WIDTH-1:0] value_o,
  output ht_cmd_t          cmd_o,
  output ht_res_t          res_o,
  output                   val_o,
  input                    ready_i

);

ht_if #( 
  .KEY_WIDTH      ( KEY_WIDTH        ),
  .VALUE_WIDTH    ( VALUE_WIDTH      ),
  .BUCKET_WIDTH   ( BUCKET_WIDTH     ),
  .HEAD_PTR_WIDTH ( TABLE_ADDR_WIDTH )
) ht_calc_hash ( 
  .clk            ( clk_i       ) 
);

ht_if #( 
  .KEY_WIDTH      ( KEY_WIDTH        ),
  .VALUE_WIDTH    ( VALUE_WIDTH      ),
  .BUCKET_WIDTH   ( BUCKET_WIDTH     ),
  .HEAD_PTR_WIDTH ( TABLE_ADDR_WIDTH )
) ht_head_table ( 
  .clk            ( clk_i       ) 
);

logic [BUCKET_WIDTH-1:0]     head_table_wr_addr;
logic [HEAD_PTR_WIDTH-1:0]   head_table_wr_data_ptr;
logic                        head_table_wr_data_ptr_val;
logic                        head_table_wr_en;

logic                        head_table_clear_ram_run;
logic                        head_table_clear_ram_done;

calc_hash #(
  .KEY_WIDTH                              ( KEY_WIDTH            ),
  .VALUE_WIDTH                            ( VALUE_WIDTH          ),
  .BUCKET_WIDTH                           ( BUCKET_WIDTH         ),
  .TABLE_ADDR_WIDTH                       ( TABLE_ADDR_WIDTH     ),
  .HASH_TYPE                              ( HASH_TYPE            )
) calc_hash (

  .clk_i                                  ( clk_i                ),
  .rst_i                                  ( rst_i                ),

  .ht_in                                  ( ht_in                ),
  .ht_out                                 ( ht_calc_hash         )
);

head_table #(

  .KEY_WIDTH                              ( KEY_WIDTH            ),
  .VALUE_WIDTH                            ( VALUE_WIDTH          ),
  .BUCKET_WIDTH                           ( BUCKET_WIDTH         ),
  .TABLE_ADDR_WIDTH                       ( TABLE_ADDR_WIDTH     )

) head_ptr_table (

  .clk_i                                  ( clk_i                      ),
  .rst_i                                  ( rst_i                      ),
    
  .ht_in                                  ( ht_calc_hash               ),
  .ht_out                                 ( ht_head_table              ),
    
  .wr_addr_i                              ( head_table_wr_addr         ),
  .wr_data_ptr_i                          ( head_table_wr_data_ptr     ),
  .wr_data_ptr_val_i                      ( head_table_wr_data_ptr_val ),
  .wr_en_i                                ( head_table_wr_en           ),

  .clear_ram_run_i                        ( head_table_clear_ram_run   ),
  .clear_ram_done_o                       ( head_table_clear_ram_done  )

);

endmodule
