import hash_table::*;

module hash_table_top( 

  input                    clk_i,
  input                    rst_i,
  
  ht_task_if.slave         ht_task_in,
  ht_res_if.master         ht_res_out

);

ht_if ht_in( 
  .clk            ( clk_i       ) 
);

ht_if ht_calc_hash( 
  .clk            ( clk_i       ) 
);

ht_if ht_head_table( 
  .clk            ( clk_i            ) 
);

head_table_if head_table_if(
  .clk            ( clk_i            )
);

logic     head_table_clear_ram_run;
logic     head_table_clear_ram_done;

logic     data_table_clear_ram_run;
logic     data_table_clear_ram_done;

// FIXME : it should be from auto from reset
assign head_table_clear_ram_run = 1'b0;
assign data_table_clear_ram_run = 1'b0;


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

calc_hash calc_hash (
  .clk_i                                  ( clk_i                ),
  .rst_i                                  ( rst_i                ),

  .ht_in                                  ( ht_in                ),
  .ht_out                                 ( ht_calc_hash         )
);

head_table head_ptr_table (
  .clk_i                                  ( clk_i                      ),
  .rst_i                                  ( rst_i                      ),
    
  .ht_in                                  ( ht_calc_hash               ),
  .ht_out                                 ( ht_head_table              ),
  
  .head_table_if                          ( head_table_if              ),

  .clear_ram_run_i                        ( head_table_clear_ram_run   ),
  .clear_ram_done_o                       ( head_table_clear_ram_done  )

);

data_table data_table (
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
