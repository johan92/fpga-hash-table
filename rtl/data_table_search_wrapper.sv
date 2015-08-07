import hash_table::*;

module data_table_search_wrapper #( 
  // how much use engines in parallel
  parameter ENGINES_CNT = 3,
  parameter RAM_LATENCY = 2,

  parameter A_WIDTH     = TABLE_ADDR_WIDTH
)(

  input                 clk_i,
  input                 rst_i,
  
  ht_res_if.master      ht_res_if,

  input  ram_data_t     rd_data_i, 

  output [A_WIDTH-1:0]  rd_addr_o,
  output                rd_en_o

);

logic [ENGINES_CNT-1:0][A_WIDTH-1:0] rd_addr;
logic [ENGINES_CNT-1:0]              rd_data_val;
logic [ENGINES_CNT-1:0]              rd_en;
logic [ENGINES_CNT-1:0]              rd_avail = 'd1;
logic [ENGINES_CNT-1:0]              busy_w;
logic []

// just one that goes round by round ^_^
always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    rd_avail <= 'd1;
  else
    rd_avail <= { rd_avail[ENGINES_CNT-2:0], rd_avail[ENGINES_CNT-1] };


always_ff @( posedge clk_i or posedge rst_i )



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

      data_table_search search(
        .clk_i                                  ( clk_i             ),
        .rst_i                                  ( rst_i             ),
          
        .rd_avail_i                             ( rd_avail[g]       ),
          
        .task_i                                 ( task_i            ),
        .task_run_i                             ( task_run_i        ),

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
