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

logic     head_table_clear_ram_run;
logic     head_table_clear_ram_done;

logic     data_table_clear_ram_run;
logic     data_table_clear_ram_done;

// FIXME : it should be from auto from reset
assign head_table_clear_ram_run = 1'b0;
assign data_table_clear_ram_run = 1'b0;

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

assign pdata_in_valid   = ht_cmd_in.valid;
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

head_table head_ptr_table (
  .clk_i                                  ( clk_i                      ),
  .rst_i                                  ( rst_i                      ),

  .pdata_in_i                             ( pdata_calc_hash            ),
  .pdata_in_valid_i                       ( pdata_calc_hash_valid      ),
  .pdata_in_ready_o                       ( pdata_calc_hash_ready      ),

  .pdata_out_o                            ( pdata_head_table           ),
  .pdata_out_valid_o                      ( pdata_head_table_valid     ),
  .pdata_out_ready_i                      ( pdata_head_table_ready     ),
    
  .head_table_if                          ( head_table_if              ),

  .clear_ram_run_i                        ( head_table_clear_ram_run   ),
  .clear_ram_done_o                       ( head_table_clear_ram_done  )

);

data_table data_table (
  .clk_i                                  ( clk_i                   ),
  .rst_i                                  ( rst_i                   ),

  .pdata_in_i                             ( pdata_head_table        ),
  .pdata_in_valid_i                       ( pdata_head_table_valid  ),
  .pdata_in_ready_o                       ( pdata_head_table_ready  ),

  .ht_res_out                             ( ht_res_out              ),
    
  .head_table_if                          ( head_table_if           ),

  // interface to clear [fill with zero] all ram content
  .clear_ram_run_i                        ( data_table_clear_ram_run   ),
  .clear_ram_done_o                       ( data_table_clear_ram_done  )

);

// synthesis translate_off

ht_res_monitor resm(
  .clk_i                                  ( clk_i              ),

  .result_i                               ( ht_res_out.result  ),
  .result_valid_i                         ( ht_res_out.valid   ),
  .result_ready_i                         ( ht_res_out.ready   )

);

head_ram_data_t                        tm_head_table_wr_data;
logic           [BUCKET_WIDTH-1:0]     tm_head_table_wr_addr;
logic                                  tm_head_table_wr_en;

  // data table
ram_data_t                             tm_data_table_wr_data;
logic           [TABLE_ADDR_WIDTH-1:0] tm_data_table_wr_addr;
logic                                  tm_data_table_wr_en;
logic           [TABLE_ADDR_WIDTH-1:0] tm_data_table_rd_addr;
logic                                  tm_data_table_rd_en;

logic           [TABLE_ADDR_WIDTH-1:0] empty_ptr_add_addr;
logic                                  empty_ptr_add_addr_en;

logic           [TABLE_ADDR_WIDTH-1:0] empty_ptr_del_addr;
logic                                  empty_ptr_del_addr_en;

assign tm_head_table_wr_data.ptr     = head_table_if.wr_data_ptr;
assign tm_head_table_wr_data.ptr_val = head_table_if.wr_data_ptr_val;
assign tm_head_table_wr_addr         = head_table_if.wr_addr;
assign tm_head_table_wr_en           = head_table_if.wr_en;

assign tm_data_table_wr_data         = data_table.ram_wr_data; 
assign tm_data_table_wr_addr         = data_table.ram_wr_addr;
assign tm_data_table_wr_en           = data_table.ram_wr_en;
assign tm_data_table_rd_addr         = data_table.ram_rd_addr;
assign tm_data_table_rd_en           = data_table.ram_rd_en;

assign empty_ptr_add_addr            = data_table.add_empty_ptr; 
assign empty_ptr_add_addr_en         = data_table.add_empty_ptr_en;
assign empty_ptr_del_addr            = data_table.empty_addr;
assign empty_ptr_del_addr_en         = data_table.empty_addr_rd_ack && data_table.empty_addr_val;

tables_monitor tm(

  .clk_i                                  ( clk_i                 ),
  .rst_i                                  ( rst_i                 ),

    // head_ptr table
  .head_table_wr_data_i                   ( tm_head_table_wr_data  ),
  .head_table_wr_addr_i                   ( tm_head_table_wr_addr  ),
  .head_table_wr_en_i                     ( tm_head_table_wr_en    ),

    // data table
  .data_table_wr_data_i                   ( tm_data_table_wr_data  ),
  .data_table_wr_addr_i                   ( tm_data_table_wr_addr  ),
  .data_table_wr_en_i                     ( tm_data_table_wr_en    ),

  .data_table_rd_addr_i                   ( tm_data_table_rd_addr  ),
  .data_table_rd_en_i                     ( tm_data_table_rd_en    ),

  .empty_ptr_add_addr_i                   ( empty_ptr_add_addr     ),
  .empty_ptr_add_addr_en_i                ( empty_ptr_add_addr_en  ),

  .empty_ptr_del_addr_i                   ( empty_ptr_del_addr     ),
  .empty_ptr_del_addr_en_i                ( empty_ptr_del_addr_en  )
);


// synthesis translate_on

endmodule
