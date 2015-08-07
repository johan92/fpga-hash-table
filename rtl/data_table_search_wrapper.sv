import hash_table::*;

module data_table_search_wrapper #( 
  // how much use search engines in parallel
  parameter ENGINES_CNT = 3,
  parameter RAM_LATENCY = 2,

  parameter A_WIDTH     = TABLE_ADDR_WIDTH
)(

  input                 clk_i,
  input                 rst_i,
  
  ht_if.slave           ht_if,

  //ht_res_if.master      ht_res_if,

  input  ram_data_t     rd_data_i, 

  output [A_WIDTH-1:0]  rd_addr_o,
  output                rd_en_o

);
localparam ENGINES_CNT_WIDTH = $clog2( ENGINES_CNT );

logic [ENGINES_CNT-1:0][A_WIDTH-1:0] rd_addr;
logic [ENGINES_CNT-1:0]              rd_data_val;
logic [ENGINES_CNT-1:0]              rd_en;
logic [ENGINES_CNT-1:0]              rd_avail = 'd1;
logic [ENGINES_CNT-1:0]              busy_w;

logic [ENGINES_CNT-1:0]              send_mask = 'd1;             
logic [ENGINES_CNT_WIDTH-1:0]        send_num;

ht_data_task_t task_w;
logic [ENGINES_CNT-1:0]              task_run;

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
    if( ht_if.valid && ht_if.ready )
      send_mask <= { send_mask[ENGINES_CNT-2:0], send_mask[ENGINES_CNT-1] };

ht_res_if ht_res_if[ENGINES_CNT-1:0](
  .clk(  clk_i ) 
);

always_comb
  begin
    send_num = '0;
    for( int i = 0; i < ENGINES_CNT; i++ )
      begin
        if( send_mask[i] )
          send_num = i[ENGINES_CNT_WIDTH-1:0];
      end
  end

assign ht_if.ready = !busy_w[ send_num ];


assign task_w.key          = ht_if.key; 
assign task_w.value        = ht_if.value;        
assign task_w.cmd          = SEARCH; // FIXME WTF? ht_if.cmd;          
                                                
assign task_w.bucket       = ht_if.bucket;       
                                                
assign task_w.head_ptr     = ht_if.head_ptr;     
assign task_w.head_ptr_val = ht_if.head_ptr_val; 



genvar g;
generate
  for( g = 0; g < ENGINES_CNT; g++ )
    begin
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
      
      assign task_run[g] = ( send_num == g ) && ( ht_if.ready && ht_if.valid );
      
      // FIXME, just by now
      assign ht_res_if[g].ready = 1'b1;

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

        .ht_res_if                              ( ht_res_if[g]      )
      );

    end
endgenerate

endmodule
