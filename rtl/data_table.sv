//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

import hash_table::*;

module data_table( 
  input                                clk_i,
  input                                rst_i,

  input                ht_pdata_t      pdata_in_i,
  input                                pdata_in_valid_i,
  output               logic           pdata_in_ready_o,

  ht_res_if.master                     ht_res_out,
  
  head_table_if.master                 head_table_if

);
localparam D_WIDTH     = $bits( ram_data_t );
localparam A_WIDTH     = HEAD_PTR_WIDTH;
localparam RAM_LATENCY = 2;

localparam INIT_   = 0;
localparam SEARCH_ = 1;
localparam INSERT_ = 2;
localparam DELETE_ = 3;

localparam DIR_CNT = 4; 

logic       [A_WIDTH-1:0] empty_addr;
logic                     empty_addr_val;
logic                     empty_addr_rd_ack;

logic       [A_WIDTH-1:0] init_add_empty_ptr;
logic                     init_add_empty_ptr_en;

logic       [A_WIDTH-1:0] delete_add_empty_ptr;
logic                     delete_add_empty_ptr_en;

logic       [A_WIDTH-1:0] add_empty_ptr;
logic                     add_empty_ptr_en;

ht_pdata_t           task_w;
logic                task_valid       [DIR_CNT-1:0];
logic                task_ready       [DIR_CNT-1:0];
logic                task_proccessing [DIR_CNT-1:0];

logic                search_task_in_proccess;

ht_res_if ht_eng_res[DIR_CNT-1:0]( 
  .clk ( clk_i )
);

data_table_if data_table_if[DIR_CNT-1:0](
  .clk ( clk_i )
);

data_table_if data_table_ram_if(
  .clk ( clk_i )
);

head_table_if head_table_eng_if[DIR_CNT-1:0] (
  .clk ( clk_i )
);

logic empty_ptr_storage_srst_w;

data_table_init init_eng( 
  .clk_i                                  ( clk_i                    ),
  .rst_i                                  ( rst_i                    ),

  .task_i                                 ( task_w                   ),
  .task_valid_i                           ( task_valid [INIT_]       ),
  .task_ready_o                           ( task_ready [INIT_]       ),
  
  .data_table_if                          ( data_table_if[INIT_]     ),
    
  .head_table_if                          ( head_table_eng_if[INIT_] ),

  // to empty pointer storage
  .empty_ptr_storage_srst_o               ( empty_ptr_storage_srst_w ),
  .add_empty_ptr_o                        ( init_add_empty_ptr       ),
  .add_empty_ptr_en_o                     ( init_add_empty_ptr_en    ),
    
  .ht_res_if                               ( ht_eng_res[INIT_]       )

);

data_table_search_wrapper #( 
  .ENGINES_CNT                            ( 5                          ),
  .RAM_LATENCY                            ( RAM_LATENCY                )
) sea_eng (

  .clk_i                                  ( clk_i                      ),
  .rst_i                                  ( rst_i                      ),
    
  .task_i                                 ( task_w                     ),
  .task_valid_i                           ( task_valid       [SEARCH_] ),
  .task_ready_o                           ( task_ready       [SEARCH_] ),

  .task_in_proccess_o                     ( search_task_in_proccess    ),
  
  .data_table_if                          ( data_table_if[SEARCH_]     ),

  .head_table_if                          ( head_table_eng_if[SEARCH_] ),

  .ht_res_if                              ( ht_eng_res[SEARCH_]        )
);

data_table_insert #(
  .RAM_LATENCY                            ( RAM_LATENCY                 )
) ins_eng (
  .clk_i                                  ( clk_i                       ),
  .rst_i                                  ( rst_i                       ),
    
  .task_i                                 ( task_w                      ),
  .task_valid_i                           ( task_valid       [INSERT_]  ),
  .task_ready_o                           ( task_ready       [INSERT_]  ),

  .data_table_if                          ( data_table_if    [INSERT_]  ),
    
    // to empty pointer storage
  .empty_addr_i                           ( empty_addr                  ),
  .empty_addr_val_i                       ( empty_addr_val              ),
  .empty_addr_rd_ack_o                    ( empty_addr_rd_ack           ),

  .head_table_if                          ( head_table_eng_if[INSERT_]  ),

  .ht_res_if                              ( ht_eng_res[INSERT_]         )
);

data_table_delete #(
  .RAM_LATENCY                            ( RAM_LATENCY                     )
) del_eng ( 
  .clk_i                                  ( clk_i                           ),
  .rst_i                                  ( rst_i                           ),
    
  .task_i                                 ( task_w                          ),
  .task_valid_i                           ( task_valid       [DELETE_]      ),
  .task_ready_o                           ( task_ready       [DELETE_]      ),

    // to data RAM                                           
  .data_table_if                          ( data_table_if    [DELETE_]      ),
    
    // to empty pointer storage
  .add_empty_ptr_o                        ( delete_add_empty_ptr            ),
  .add_empty_ptr_en_o                     ( delete_add_empty_ptr_en         ),

  .head_table_if                          ( head_table_eng_if [DELETE_]     ),

  .ht_res_if                              ( ht_eng_res[DELETE_]             )
);

assign task_w = pdata_in_i;

assign task_proccessing[ INIT_   ] = !task_ready[ INIT_   ];
assign task_proccessing[ SEARCH_ ] = search_task_in_proccess;
assign task_proccessing[ INSERT_ ] = !task_ready[ INSERT_ ];
assign task_proccessing[ DELETE_ ] = !task_ready[ DELETE_ ];

always_comb
  begin
    pdata_in_ready_o = 1'b1;
    
    task_valid[ INIT_   ] = pdata_in_valid_i && ( task_w.cmd.opcode == OP_INIT   );
    task_valid[ SEARCH_ ] = pdata_in_valid_i && ( task_w.cmd.opcode == OP_SEARCH );
    task_valid[ INSERT_ ] = pdata_in_valid_i && ( task_w.cmd.opcode == OP_INSERT );
    task_valid[ DELETE_ ] = pdata_in_valid_i && ( task_w.cmd.opcode == OP_DELETE );
    
    case( task_w.cmd.opcode )
      OP_INIT:
        begin
          if( task_proccessing[ SEARCH_ ] || task_proccessing[ INSERT_ ] || 
              task_proccessing[ DELETE_ ] )
              begin
                pdata_in_ready_o    = 1'b0;
                task_valid[ INIT_ ] = 1'b0;
              end
          else
            begin
              pdata_in_ready_o = task_ready[ INIT_ ];
            end
        end

      OP_SEARCH:
        begin
          if( task_proccessing[ INIT_   ] || task_proccessing[ INSERT_ ] || 
              task_proccessing[ DELETE_ ] )
            begin
              pdata_in_ready_o      = 1'b0;
              task_valid[ SEARCH_ ] = 1'b0;
            end
          else
            begin
              pdata_in_ready_o = task_ready[ SEARCH_ ];
            end
        end

      OP_INSERT:
        begin
          if( task_proccessing[ INIT_   ] || task_proccessing[ SEARCH_ ] || 
              task_proccessing[ DELETE_ ] )
            begin
              pdata_in_ready_o      = 1'b0;
              task_valid[ INSERT_ ] = 1'b0;
            end
          else
            pdata_in_ready_o = task_ready[ INSERT_ ];
        end

      OP_DELETE:
        begin
          if( task_proccessing[ INIT_   ] || task_proccessing[ SEARCH_ ] || 
              task_proccessing[ INSERT_ ] )
            begin
              pdata_in_ready_o      = 1'b0;
              task_valid[ DELETE_ ] = 1'b0;
            end
          else
            pdata_in_ready_o = task_ready[ DELETE_ ];
        end

      default: 
        begin
          pdata_in_ready_o = 1'b1;
        end
    endcase
  end


// ******* MUX to RAM *******

data_table_if_mux #(
  .DIR_CNT                                ( DIR_CNT           )
) data_table_mux (

  .dt_in_if                               ( data_table_if     ),
  .dt_out_if                              ( data_table_ram_if )

);

// ******* MUX to head_table *******

head_table_if_mux #(
  .DIR_CNT                                ( DIR_CNT           )
) head_table_if_mux (
  .in_if                                  ( head_table_eng_if ),
  .out_if                                 ( head_table_if     )
);

// ******* Muxing cmd result *******

ht_res_mux #(
  .DIR_CNT                                ( DIR_CNT           )
) res_mux (

  .ht_res_in                              ( ht_eng_res        ),
  .ht_res_out                             ( ht_res_out        )

);
// ******* Empty ptr store *******

always_comb
  begin
    if( init_add_empty_ptr_en )
      begin
        add_empty_ptr     = init_add_empty_ptr; 
        add_empty_ptr_en  = init_add_empty_ptr_en;
      end
    else
      begin
        add_empty_ptr     = delete_add_empty_ptr; 
        add_empty_ptr_en  = delete_add_empty_ptr_en;
      end
  end


empty_ptr_storage #(
  .A_WIDTH                                ( TABLE_ADDR_WIDTH  )
) empty_ptr_storage (

  .clk_i                                  ( clk_i             ),
  .rst_i                                  ( rst_i             ),

  .srst_i                                 ( empty_ptr_storage_srst_w ),
    
  .add_empty_ptr_i                        ( add_empty_ptr     ),
  .add_empty_ptr_en_i                     ( add_empty_ptr_en  ),
    
  .next_empty_ptr_rd_ack_i                ( empty_addr_rd_ack ),
  .next_empty_ptr_o                       ( empty_addr        ),
  .next_empty_ptr_val_o                   ( empty_addr_val    )

);

true_dual_port_ram_single_clock #( 
  .DATA_WIDTH                             ( D_WIDTH                   ), 
  .ADDR_WIDTH                             ( A_WIDTH                   ), 
  .REGISTER_OUT                           ( 1                         )
) data_ram (
  .clk                                    ( clk_i                     ),

  .addr_a                                 ( data_table_ram_if.rd_addr ),
  .data_a                                 ( {D_WIDTH{1'b0}}           ),
  .we_a                                   ( 1'b0                      ),
  .re_a                                   ( 1'b1                      ),
  .q_a                                    ( data_table_ram_if.rd_data ),

  .addr_b                                 ( data_table_ram_if.wr_addr ),
  .data_b                                 ( data_table_ram_if.wr_data ),
  .we_b                                   ( data_table_ram_if.wr_en   ),
  .re_b                                   ( 1'b0                      ),
  .q_b                                    (                           )
);


endmodule
