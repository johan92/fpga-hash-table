module head_table #(

  parameter KEY_WIDTH      = 32,
  parameter VALUE_WIDTH    = 16,
  parameter BUCKET_WIDTH   = 8,
  parameter HEAD_PTR_WIDTH = 10

)(

  input                        clk_i,
  input                        rst_i,
  
  ht_if.slave                  ht_in,
  ht_if.master                 ht_out,
  
  head_table_if.slave          head_table_if,

  // interface to clear [fill with zero] all ram content
  input                        clear_ram_run_i,
  output logic                 clear_ram_done_o

);

typedef struct packed {
  logic [HEAD_PTR_WIDTH-1:0] ptr;
  logic                      ptr_val;
} head_ram_data_t;

localparam D_WIDTH = $bits( head_ram_data_t );
localparam A_WIDTH = BUCKET_WIDTH;

logic [A_WIDTH-1:0]    wr_addr;
logic [A_WIDTH-1:0]    rd_addr;

head_ram_data_t        wr_data;
head_ram_data_t        rd_data;
logic                  wr_en;

assign rd_addr = ht_in.bucket;

true_dual_port_ram_single_clock #( 
  .DATA_WIDTH                             ( D_WIDTH           ), 
  .ADDR_WIDTH                             ( A_WIDTH           ), 
  .REGISTER_OUT                           ( 0                 )
) head_ram (
  .clk                                    ( clk_i             ),

  .addr_a                                 ( rd_addr           ),
  .data_a                                 ( {D_WIDTH{1'b0}}   ),
  .we_a                                   ( 1'b0              ),
  .q_a                                    ( rd_data           ),

  .addr_b                                 ( wr_addr           ),
  .data_b                                 ( wr_data           ),
  .we_b                                   ( wr_en             ),
  .q_b                                    (                   )
);

// clear RAM stuff
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

assign wr_addr          = ( clear_ram_flag ) ? ( clear_addr ) : ( head_table_if.wr_addr         );
assign wr_data.ptr      = ( clear_ram_flag ) ? ( '0         ) : ( head_table_if.wr_data_ptr     );
assign wr_data.ptr_val  = ( clear_ram_flag ) ? ( 1'b0       ) : ( head_table_if.wr_data_ptr_val );
assign wr_en            = ( clear_ram_flag ) ? ( 1'b1       ) : ( head_table_if.wr_en           ); 
assign clear_ram_done_o = clear_ram_flag && ( clear_addr == '1 );

localparam TUSER_WIDTH = $bits( head_ram_data_t );

ht_if #( 
  .KEY_WIDTH      ( KEY_WIDTH      ),
  .VALUE_WIDTH    ( VALUE_WIDTH    ),
  .BUCKET_WIDTH   ( BUCKET_WIDTH   ),
  .HEAD_PTR_WIDTH ( HEAD_PTR_WIDTH )
) ht_in_d1 ( 
  .clk            ( clk_i          ) 
);

ht_if #( 
  .KEY_WIDTH      ( KEY_WIDTH        ),
  .VALUE_WIDTH    ( VALUE_WIDTH      ),
  .BUCKET_WIDTH   ( BUCKET_WIDTH     ),
  .HEAD_PTR_WIDTH ( HEAD_PTR_WIDTH   )
) ht_w_head_ptr ( 
  .clk            ( clk_i       ) 
);

ht_delay #(
  .KEY_WIDTH                              ( KEY_WIDTH         ),
  .VALUE_WIDTH                            ( VALUE_WIDTH       ),

  .BUCKET_WIDTH                           ( BUCKET_WIDTH      ),
  .HEAD_PTR_WIDTH                         ( HEAD_PTR_WIDTH    ),

  .DELAY                                  ( 1                 ),
  .PIPELINE_READY                         ( 0                 )
) ht_d1 (
  .clk_i                                  ( clk_i             ),
  .rst_i                                  ( rst_i             ),

  .ht_in                                  ( ht_in             ),
  .ht_out                                 ( ht_in_d1          )

);

assign ht_out.key          = ht_in_d1.key; 
assign ht_out.value        = ht_in_d1.value;
assign ht_out.cmd          = ht_in_d1.cmd;

assign ht_out.bucket       = ht_in_d1.bucket;

assign ht_out.head_ptr     = rd_data.ptr; 
assign ht_out.head_ptr_val = rd_data.ptr_val;

assign ht_out.valid        = ht_in_d1.valid;

assign ht_in_d1.ready      = ht_out.ready;


// synthesis translate_off
clocking cb @( posedge clk_i );
endclocking

task write_to_head_ptr_ram(
  input bit [BUCKET_WIDTH-1:0]   _addr,
        bit [HEAD_PTR_WIDTH-1:0] _head_ptr,
        bit                      _head_ptr_val
);
  head_ram_data_t _wr_data;

  _wr_data.head_ptr     = _head_ptr;
  _wr_data.head_ptr_val = _head_ptr_val;

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
