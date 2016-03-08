//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

import hash_table::*;

module data_table_search_wrapper #( 
  // how much use search engines in parallel
  parameter ENGINES_CNT = 3,
  parameter RAM_LATENCY = 2,

  parameter A_WIDTH     = TABLE_ADDR_WIDTH
)(

  input                       clk_i,
  input                       rst_i,
  
  input  ht_pdata_t           task_i,
  input                       task_valid_i,
  output                      task_ready_o,

  // at least one task in proccess
  output logic                task_in_proccess_o, 
  
  // reading from data RAM
  data_table_if.master        data_table_if,
  
  // output interface with search result
  ht_res_if.master            ht_res_if

);
localparam ENGINES_CNT_WIDTH = $clog2( ENGINES_CNT );

logic [ENGINES_CNT-1:0][A_WIDTH-1:0] rd_addr;
logic [ENGINES_CNT-1:0]              rd_data_val;
logic [ENGINES_CNT-1:0]              rd_en;
logic [ENGINES_CNT-1:0]              rd_avail = 'd1;

logic [ENGINES_CNT-1:0]              send_mask = 'd1;             
logic [ENGINES_CNT_WIDTH-1:0]        send_num;

logic [ENGINES_CNT-1:0]              task_valid;
logic [ENGINES_CNT-1:0]              task_ready_w;

logic [ENGINES_CNT_WIDTH-1:0]        res_collector_num;

ht_result_t                          result [ENGINES_CNT-1:0];
logic [ENGINES_CNT-1:0]              result_valid;
logic [ENGINES_CNT-1:0]              result_ready;

// just one that goes round by round ^_^
always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    rd_avail <= 'd1;
  else
    rd_avail <= { rd_avail[ENGINES_CNT-2:0], rd_avail[ENGINES_CNT-1] };


always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    send_mask <= 'd1;
  else
    if( task_valid_i && task_ready_o )
      send_mask <= { send_mask[ENGINES_CNT-2:0], send_mask[ENGINES_CNT-1] };


always_comb
  begin
    send_num = '0;
    for( int i = 0; i < ENGINES_CNT; i++ )
      begin
        if( send_mask[i] )
          send_num = i[ENGINES_CNT_WIDTH-1:0];
      end
  end

assign task_ready_o = task_ready_w[ send_num ];

always_comb
  begin
    task_in_proccess_o = 1'b0;

    for( int i = 0; i < ENGINES_CNT; i++ )
      begin
        if( task_ready_w[i] == 1'b0 )
          task_in_proccess_o = 1'b1; 
      end
  end

genvar g;
generate
  for( g = 0; g < ENGINES_CNT; g++ )
    begin : g_s_eng // generate search engines

      rd_data_val_helper #( 
        .RAM_LATENCY                          ( RAM_LATENCY     ) 
      ) rd_data_val_helper (
        .clk_i                                ( clk_i           ),
        .rst_i                                ( rst_i           ),

        .rd_en_i                              ( rd_en[g]        ),
        .rd_data_val_o                        ( rd_data_val[g]  )

      );

      assign task_valid[g] = ( send_num == g ) && ( task_ready_o && task_valid_i );
      
      data_table_search search(
        .clk_i                                  ( clk_i             ),
        .rst_i                                  ( rst_i             ),
          
        .task_i                                 ( task_i            ),
        .task_valid_i                           ( task_valid[g]     ),
        .task_ready_o                           ( task_ready_w[g]   ),

        .rd_avail_i                             ( rd_avail[g]       ),
        .rd_data_i                              ( data_table_if.rd_data ),
        .rd_data_val_i                          ( rd_data_val[g]    ),

        .rd_addr_o                              ( rd_addr[g]        ),
        .rd_en_o                                ( rd_en[g]          ),

        .result_o                               ( result[g]         ),
        .result_valid_o                         ( result_valid[g]   ),
        .result_ready_i                         ( result_ready[g]   )
      );

    end
endgenerate

always_comb
  begin
    // dummy selector realization
    data_table_if.rd_addr = '0;
    data_table_if.rd_en   = 1'b0;

    for( int i = 0; i < ENGINES_CNT; i++ )
      begin
        if( rd_en[ i ] )
          begin
            data_table_if.rd_addr = rd_addr[ i ];
            data_table_if.rd_en   = 1'b1;
          end
      end
  end

// no write support here
assign data_table_if.wr_addr = 'x;
assign data_table_if.wr_data = 'x;
assign data_table_if.wr_en   = 1'b0;

// collecting results in right order
always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    res_collector_num <= '0;
  else
    if( ht_res_if.ready && ht_res_if.valid )
      begin
        if( res_collector_num == ( ENGINES_CNT - 1 ) )
          res_collector_num <= '0;
        else 
          res_collector_num <= res_collector_num + 1'd1;
      end

assign ht_res_if.result  = result[ res_collector_num ];
assign ht_res_if.valid   = result_valid[ res_collector_num ];

always_comb
  begin
    for( int i = 0; i < ENGINES_CNT; i++ )
      begin
        result_ready[i] = ( i == res_collector_num ) ? ( ht_res_if.ready ) : ( 1'b0 );
      end
  end

endmodule
