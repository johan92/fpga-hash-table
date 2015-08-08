import hash_table::*;

module data_table_search_wrapper #( 
  // how much use search engines in parallel
  parameter ENGINES_CNT = 3,
  parameter RAM_LATENCY = 2,

  parameter A_WIDTH     = TABLE_ADDR_WIDTH
)(

  input                       clk_i,
  input                       rst_i,
  
  ht_if.slave                 ht_if_1,
  
  // reading from data RAM
  input  ram_data_t           rd_data_i, 

  output logic [A_WIDTH-1:0]  rd_addr_o,
  output logic                rd_en_o,
  
  // output interface with search result
  output ht_result_t          result_o,
  output logic                result_valid_o,
  input                       result_ready_i

);
localparam ENGINES_CNT_WIDTH = $clog2( ENGINES_CNT );

logic [ENGINES_CNT-1:0][A_WIDTH-1:0] rd_addr;
logic [ENGINES_CNT-1:0]              rd_data_val;
logic [ENGINES_CNT-1:0]              rd_en;
logic [ENGINES_CNT-1:0]              rd_avail = 'd1;
logic [ENGINES_CNT-1:0]              busy_w;

logic [ENGINES_CNT-1:0]              send_mask = 'd1;             
logic [ENGINES_CNT_WIDTH-1:0]        send_num;

ht_data_task_t                       task_w;
logic [ENGINES_CNT-1:0]              task_run;

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
    if( ht_if_1.valid && ht_if_1.ready )
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

assign ht_if_1.ready = !busy_w[ send_num ];

assign task_w.key          = ht_if_1.key; 
assign task_w.value        = ht_if_1.value;        
assign task_w.cmd          = ht_if_1.cmd;          
                                                
assign task_w.bucket       = ht_if_1.bucket;       
                                                
assign task_w.head_ptr     = ht_if_1.head_ptr;     
assign task_w.head_ptr_val = ht_if_1.head_ptr_val; 


genvar g;
generate
  for( g = 0; g < ENGINES_CNT; g++ )
    begin : g_s_eng // generate search engines
      logic [RAM_LATENCY:1] l_rd_en_d;

      always_ff @( posedge clk_i or posedge rst_i )
        if( rst_i )
          l_rd_en_d <= '0;
        else
          begin
            l_rd_en_d[1] <= rd_en[g];

            for( int i = 2; i <= RAM_LATENCY; i++ )
              begin
                l_rd_en_d[ i ] <= l_rd_en_d[ i - 1 ];
              end
          end
      
      // we know ram latency, so expecting data valid 
      // just delaying this tick count
      assign rd_data_val[g] = l_rd_en_d[RAM_LATENCY];
      
      assign task_run[g] = ( send_num == g ) && ( ht_if_1.ready && ht_if_1.valid );
      
      data_table_search search(
        .clk_i                                  ( clk_i             ),
        .rst_i                                  ( rst_i             ),
          
        .rd_avail_i                             ( rd_avail[g]       ),
          
        .task_i                                 ( task_w            ),
        .task_run_i                             ( task_run[g]       ),

        .busy_o                                 ( busy_w[g]         ),

        .rd_data_i                              ( rd_data_i         ),
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
    rd_addr_o = '0;
    rd_en_o   = 1'b0;

    for( int i = 0; i < ENGINES_CNT; i++ )
      begin
        if( rd_en[ i ] )
          begin
            rd_addr_o = rd_addr[ i ];
            rd_en_o   = 1'b1;
          end
      end
  end

// collecting results in right order
always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    res_collector_num <= '0;
  else
    if( result_ready_i && result_valid_o )
      begin
        if( res_collector_num == ( ENGINES_CNT - 1 ) )
          res_collector_num <= '0;
        else 
          res_collector_num <= res_collector_num + 1'd1;
      end

assign result_o       = result[ res_collector_num ];
assign result_valid_o = result_valid[ res_collector_num ];

always_comb
  begin
    for( int i = 0; i < ENGINES_CNT; i++ )
      begin
        result_ready[i] = ( i == res_collector_num ) ? ( result_ready_i ) : ( 1'b0 );
      end
  end

endmodule
