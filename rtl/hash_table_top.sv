import hash_table::*;

module hash_table_top #( 
  parameter KEY_WIDTH        = 32,
  parameter VALUE_WIDTH      = 16,
  parameter BUCKET_WIDTH     = 8,
  parameter HASH_TYPE        = "dummy",
  parameter TABLE_ADDR_WIDTH = 10
)(

  input                    clk_i,
  input                    rst_i,
  
  ht_task_if.slave         ht_task_in,
  ht_res_if.master         ht_res_out

);

ht_if #( 
  .KEY_WIDTH      ( KEY_WIDTH        ),
  .VALUE_WIDTH    ( VALUE_WIDTH      ),
  .BUCKET_WIDTH   ( BUCKET_WIDTH     ),
  .HEAD_PTR_WIDTH ( TABLE_ADDR_WIDTH )
) ht_in ( 
  .clk            ( clk_i       ) 
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
  .clk            ( clk_i            ) 
);

head_table_if #(
  .A_WIDTH        ( BUCKET_WIDTH     ),
  .HEAD_PTR_WIDTH ( TABLE_ADDR_WIDTH )
) head_table_if(
  .clk            ( clk_i            )
);

logic     head_table_clear_ram_run;
logic     head_table_clear_ram_done;

logic     data_table_clear_ram_run;
logic     data_table_clear_ram_done;

// just reassigning to ht_in interface
// zeroing bucket and head_ptr stuff because there no data about it
// at this pipeline stage
assign ht_in.key           = ht_task_in.key;
assign ht_in.value         = ht_task_in.value;
assign ht_in.cmd           = ht_task_in.cmd;

assign ht_in.bucket        = '0;
assign ht_in.head_ptr      = '0;
assign ht_in.head_ptr_val  = '0;

assign ht_in.valid         = ht_task_in.valid;
assign ht_task_in.ready    = ht_in.ready;

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
  .HEAD_PTR_WIDTH                         ( TABLE_ADDR_WIDTH     )

) head_ptr_table (

  .clk_i                                  ( clk_i                      ),
  .rst_i                                  ( rst_i                      ),
    
  .ht_in                                  ( ht_calc_hash               ),
  .ht_out                                 ( ht_head_table              ),
  
  .head_table_if                          ( head_table_if              ),

  .clear_ram_run_i                        ( head_table_clear_ram_run   ),
  .clear_ram_done_o                       ( head_table_clear_ram_done  )

);

data_table #( 
  .KEY_WIDTH                              ( KEY_WIDTH            ),
  .VALUE_WIDTH                            ( VALUE_WIDTH          ),
  .BUCKET_WIDTH                           ( BUCKET_WIDTH         ),
  .TABLE_ADDR_WIDTH                       ( TABLE_ADDR_WIDTH     )
) data_table (
  .clk_i                                  ( clk_i                      ),
  .rst_i                                  ( rst_i                      ),

  .ht_in                                  ( ht_head_table              ),
  .ht_res_out                             ( ht_res_out                 ),
    
  .head_table_if                          ( head_table_if              ),

  // interface to clear [fill with zero] all ram content
  .clear_ram_run_i                        ( data_table_clear_ram_run   ),
  .clear_ram_done_o                       ( data_table_clear_ram_done  )

);

endmodule
