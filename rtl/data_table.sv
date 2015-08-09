import hash_table::*;

module data_table( 
  input                clk_i,
  input                rst_i,

  ht_if.slave          ht_in,
  ht_res_if.master     ht_res_out,
  
  head_table_if.master head_table_if,

  // interface to clear [fill with zero] all ram content
  input                clear_ram_run_i,
  output logic         clear_ram_done_o

);
localparam D_WIDTH     = $bits( ram_data_t );
localparam A_WIDTH     = HEAD_PTR_WIDTH;
localparam RAM_LATENCY = 2;

localparam SEARCH_ = 0;
localparam INSERT_ = 1;
localparam DELETE_ = 2;

localparam DIR_CNT = 3; 
localparam DIR_CNT_WIDTH = $clog2( DIR_CNT );

ram_data_t                ram_rd_data;

logic      [A_WIDTH-1:0]  ram_rd_addr;
logic                     ram_rd_en;

logic      [A_WIDTH-1:0]  ram_wr_addr;
ram_data_t                ram_wr_data;
logic                     ram_wr_en;

logic       [A_WIDTH-1:0] rd_addr_w [DIR_CNT-1:0];
logic                     rd_en_w   [DIR_CNT-1:0];

logic       [A_WIDTH-1:0] wr_addr_w [DIR_CNT-1:0];
ram_data_t                wr_data_w [DIR_CNT-1:0];
logic                     wr_en_w   [DIR_CNT-1:0];

ht_result_t               cmd_result        [DIR_CNT-1:0];
logic                     cmd_result_valid  [DIR_CNT-1:0]; 
logic                     cmd_result_ready  [DIR_CNT-1:0];

logic       [A_WIDTH-1:0] empty_addr;
logic                     empty_addr_val;
logic                     empty_addr_rd_ack;

logic       [A_WIDTH-1:0] add_empty_ptr;
logic                     add_empty_ptr_en;

ht_data_task_t       task_w;
logic                task_valid       [DIR_CNT-1:0];
logic                task_ready       [DIR_CNT-1:0];
logic                task_proccessing [DIR_CNT-1:0];

logic                search_task_in_proccess;

head_table_if head_table_insert_if( 
  .clk( clk_i )
);

head_table_if head_table_delete_if( 
  .clk( clk_i )
);

data_table_search_wrapper #( 
  .ENGINES_CNT                            ( 5                          ),
  .RAM_LATENCY                            ( RAM_LATENCY                )
) search_engine (

  .clk_i                                  ( clk_i                      ),
  .rst_i                                  ( rst_i                      ),
    
  .task_i                                 ( task_w                     ),
  .task_valid_i                           ( task_valid       [SEARCH_]  ),
  .task_ready_o                           ( task_ready       [SEARCH_]  ),

  .task_in_proccess_o                     ( search_task_in_proccess    ),

  .rd_data_i                              ( ram_rd_data                ),
  .rd_addr_o                              ( rd_addr_w        [SEARCH_]  ),
  .rd_en_o                                ( rd_en_w          [SEARCH_]  ),

  .result_o                               ( cmd_result       [SEARCH_]  ),
  .result_valid_o                         ( cmd_result_valid [SEARCH_]  ),
  .result_ready_i                         ( cmd_result_ready [SEARCH_]  )
);

// for search no need in write interface to RAM
assign wr_addr_w[SEARCH_] = '0;
assign wr_data_w[SEARCH_] = '0;
assign wr_en_w  [SEARCH_] = 1'b0;

data_table_insert #(
  .RAM_LATENCY                            ( RAM_LATENCY                 )
) insert_engine (
  .clk_i                                  ( clk_i                       ),
  .rst_i                                  ( rst_i                       ),
    
  .task_i                                 ( task_w                      ),
  .task_valid_i                           ( task_valid       [INSERT_]  ),
  .task_ready_o                           ( task_ready       [INSERT_]  ),
    
    // to data RAM
  .rd_data_i                              ( ram_rd_data                 ),
  .rd_addr_o                              ( rd_addr_w        [INSERT_]  ),
  .rd_en_o                                ( rd_en_w          [INSERT_]  ),

  .wr_addr_o                              ( wr_addr_w        [INSERT_]  ),
  .wr_data_o                              ( wr_data_w        [INSERT_]  ),
  .wr_en_o                                ( wr_en_w          [INSERT_]  ),
    
    // to empty pointer storage
  .empty_addr_i                           ( empty_addr        ),
  .empty_addr_val_i                       ( empty_addr_val    ),
  .empty_addr_rd_ack_o                    ( empty_addr_rd_ack ),

  .head_table_if                          ( head_table_insert_if         ),

    // output interface with search result
  .result_o                               ( cmd_result       [INSERT_]   ),
  .result_valid_o                         ( cmd_result_valid [INSERT_]   ),
  .result_ready_i                         ( cmd_result_ready [INSERT_]   )
);

data_table_delete #(
  .RAM_LATENCY                            ( RAM_LATENCY                     )
) delete_engine ( 
  .clk_i                                  ( clk_i                           ),
  .rst_i                                  ( rst_i                           ),
    
  .task_i                                 ( task_w                          ),
  .task_valid_i                           ( task_valid       [DELETE_]      ),
  .task_ready_o                           ( task_ready       [DELETE_]      ),

    // to data RAM                                            
  .rd_data_i                              ( ram_rd_data                     ),
  .rd_addr_o                              ( rd_addr_w        [DELETE_]      ),
  .rd_en_o                                ( rd_en_w          [DELETE_]      ),
  
  .wr_addr_o                              ( wr_addr_w        [DELETE_]      ),
  .wr_data_o                              ( wr_data_w        [DELETE_]      ),
  .wr_en_o                                ( wr_en_w          [DELETE_]      ),
    
    // to empty pointer storage
  .add_empty_ptr_o                        ( add_empty_ptr                   ),
  .add_empty_ptr_en_o                     ( add_empty_ptr_en                ),

  .head_table_if                          ( head_table_delete_if            ),

    // output interface with search result
  .result_o                               ( cmd_result       [DELETE_]      ),
  .result_valid_o                         ( cmd_result_valid [DELETE_]      ),
  .result_ready_i                         ( cmd_result_ready [DELETE_]      )
);
assign task_w.key          = ht_in.key; 
assign task_w.value        = ht_in.value;        
assign task_w.cmd          = ht_in.cmd;          

assign task_w.bucket       = ht_in.bucket;       

assign task_w.head_ptr     = ht_in.head_ptr;     
assign task_w.head_ptr_val = ht_in.head_ptr_val; 

assign task_proccessing[ SEARCH_ ] = search_task_in_proccess;
assign task_proccessing[ INSERT_ ] = !task_ready[ INSERT_ ];
assign task_proccessing[ DELETE_ ] = !task_ready[ DELETE_ ];

always_comb
  begin
    ht_in.ready           = 1'b1;

    task_valid[ SEARCH_ ] = ht_in.valid && ( task_w.cmd == SEARCH );
    task_valid[ INSERT_ ] = ht_in.valid && ( task_w.cmd == INSERT );
    task_valid[ DELETE_ ] = ht_in.valid && ( task_w.cmd == DELETE );
    
    case( task_w.cmd )
      SEARCH:
        begin
          if( task_proccessing[ INSERT_ ] || task_proccessing[ DELETE_ ] )
            begin
              ht_in.ready           = 1'b0;
              task_valid[ SEARCH_ ] = 1'b0;
            end
          else
            begin
              ht_in.ready = task_ready[ SEARCH_ ];
            end
        end

      INSERT:
        begin
          if( task_proccessing[ SEARCH_ ] || task_proccessing[ DELETE_ ] )
            begin
              ht_in.ready           = 1'b0;
              task_valid[ INSERT_ ] = 1'b0;
            end
          else
            ht_in.ready = task_ready[ INSERT_ ];
        end

      DELETE:
        begin
          if( task_proccessing[ SEARCH_ ] || task_proccessing[ INSERT_ ] )
            begin
              ht_in.ready           = 1'b0;
              task_valid[ DELETE_ ] = 1'b0;
            end
          else
            ht_in.ready = task_ready[ DELETE_ ];
        end

      default: 
        begin
          ht_in.ready = 1'b1;
        end
    endcase
  end


// ******* MUX to RAM *******
logic [DIR_CNT_WIDTH-1:0] rd_sel;
logic [DIR_CNT_WIDTH-1:0] wr_sel;

always_comb
  begin
    rd_sel = '0;

    for( int i = 0; i < DIR_CNT; i++ )
      begin
        if( rd_en_w[i] )
          rd_sel = i[DIR_CNT_WIDTH-1:0];
      end
  end

always_comb
  begin
    wr_sel = '0;

    for( int i = 0; i < DIR_CNT; i++ )
      begin
        if( wr_en_w[i] )
          wr_sel = i[DIR_CNT_WIDTH-1:0];
      end
  end

assign ram_rd_addr = rd_addr_w [ rd_sel ];
assign ram_rd_en   = rd_en_w   [ rd_sel ];

assign ram_wr_addr = wr_addr_w [ wr_sel ];
assign ram_wr_data = wr_data_w [ wr_sel ];
assign ram_wr_en   = wr_en_w   [ wr_sel ];  

// ******* MUX to head_table *******
always_comb
  begin
    if( head_table_insert_if.wr_en )
      begin
        head_table_if.wr_addr         = head_table_insert_if.wr_addr;         
        head_table_if.wr_data_ptr     = head_table_insert_if.wr_data_ptr;     
        head_table_if.wr_data_ptr_val = head_table_insert_if.wr_data_ptr_val;
        head_table_if.wr_en           = head_table_insert_if.wr_en; 
      end
    else
      begin
        head_table_if.wr_addr         = head_table_delete_if.wr_addr;         
        head_table_if.wr_data_ptr     = head_table_delete_if.wr_data_ptr;     
        head_table_if.wr_data_ptr_val = head_table_delete_if.wr_data_ptr_val;
        head_table_if.wr_en           = head_table_delete_if.wr_en; 
      end
  end

// ******* Muxing cmd result *******
ht_result_t               mux_cmd_result;
logic                     mux_cmd_result_valid; 

logic [DIR_CNT_WIDTH-1:0] cmd_sel;

always_comb
  begin
    cmd_sel = '0;
    for( int i = 0; i < DIR_CNT; i++ )
      begin
        // hope only one cmd_result_valid is valid
        if( cmd_result_valid[i] )
          cmd_sel = i[DIR_CNT_WIDTH-1:0];
      end
  end

assign mux_cmd_result        = cmd_result[ cmd_sel ];
assign mux_cmd_result_valid  = cmd_result_valid[ cmd_sel ];

always_comb
  begin
    for( int i = 0; i < DIR_CNT; i++ )
      begin
        cmd_result_ready[i] = !cmd_result_valid[i];
      end

    cmd_result_ready[ cmd_sel ] = ht_res_out.ready;
  end

assign ht_res_out.key   = mux_cmd_result.key;    
assign ht_res_out.value = mux_cmd_result.value;  
assign ht_res_out.cmd   = mux_cmd_result.cmd;    
assign ht_res_out.res   = mux_cmd_result.res;    
assign ht_res_out.valid = mux_cmd_result_valid; 

// ******* Empty ptr store *******

empty_ptr_storage #(
  .A_WIDTH                                ( TABLE_ADDR_WIDTH  )
) empty_ptr_storage (

  .clk_i                                  ( clk_i             ),
  .rst_i                                  ( rst_i             ),
    
  .add_empty_ptr_i                        ( add_empty_ptr     ),
  .add_empty_ptr_en_i                     ( add_empty_ptr_en  ),
    
  .next_empty_ptr_rd_ack_i                ( empty_addr_rd_ack ),
  .next_empty_ptr_o                       ( empty_addr        ),
  .next_empty_ptr_val_o                   ( empty_addr_val    )

);

// ******* Clear RAM logic *******
logic               clear_ram_flag;
logic [A_WIDTH-1:0] clear_addr;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    clear_ram_flag <= 1'b0;
  else
    begin
      if( clear_ram_run_i )
        clear_ram_flag <= 1'b1;

      if( clear_ram_done_o )
        clear_ram_flag <= 1'b0;
    end
    
always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    clear_addr <= '0;
  else
    if( clear_ram_run_i )
      clear_addr <= '0;
    else
      if( clear_ram_flag )
        clear_addr <= clear_addr + 1'd1;

assign wr_addr          = '0; // ( clear_ram_flag ) ? ( clear_addr ) : ( 'x ); //FIXME
assign wr_data          = '0; // ( clear_ram_flag ) ? ( '0         ) : ( 'x );
assign wr_en            = '0; // ( clear_ram_flag ) ? ( 1'b1       ) : ( 'x ); 
assign clear_ram_done_o = clear_ram_flag && ( clear_addr == '1 );

true_dual_port_ram_single_clock #( 
  .DATA_WIDTH                             ( D_WIDTH           ), 
  .ADDR_WIDTH                             ( A_WIDTH           ), 
  .REGISTER_OUT                           ( 1                 )
) data_ram (
  .clk                                    ( clk_i             ),

  .addr_a                                 ( ram_rd_addr       ),
  .data_a                                 ( {D_WIDTH{1'b0}}   ),
  .we_a                                   ( 1'b0              ),
  .q_a                                    ( ram_rd_data       ),

  .addr_b                                 ( ram_wr_addr       ),
  .data_b                                 ( ram_wr_data       ),
  .we_b                                   ( ram_wr_en         ),
  .q_b                                    (                   )
);

// synthesis translate_off

clocking cb @( posedge clk_i );
endclocking

task write_to_data_ram( 
  input bit [TABLE_ADDR_WIDTH-1:0] _addr, 
        bit [KEY_WIDTH-1:0]        _key,
        bit [VALUE_WIDTH-1:0]      _value,
        bit [TABLE_ADDR_WIDTH-1:0] _next_ptr,
        bit                        _next_ptr_val 
);
  ram_data_t _wr_data;

  _wr_data.key          = _key;          
  _wr_data.value        = _value;        
  _wr_data.next_ptr     = _next_ptr;     
  _wr_data.next_ptr_val = _next_ptr_val;

  @cb;
  force wr_data = _wr_data;
  force wr_addr = _addr;
  force wr_en   = 1'b0;

  @cb;
  force wr_en   = 1'b1;
  
  @cb;
  force wr_en   = 1'b0;
  
  @cb;
  release wr_data; 
  release wr_addr;
  release wr_en;
endtask                            

// synthesis translate_on

endmodule
