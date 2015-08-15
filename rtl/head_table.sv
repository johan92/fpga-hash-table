import hash_table::*;

module head_table (

  input                        clk_i,
  input                        rst_i,
  
  input        ht_pdata_t      pdata_in_i,
  input                        pdata_in_valid_i,
  output                       pdata_in_ready_o,

  output       ht_pdata_t      pdata_out_o,
  output                       pdata_out_valid_o,
  input                        pdata_out_ready_i,
  
  head_table_if.slave          head_table_if,

  // interface to clear [fill with zero] all ram content
  input                        clear_ram_run_i,
  output logic                 clear_ram_done_o

);

localparam D_WIDTH = $bits( head_ram_data_t );
localparam A_WIDTH = BUCKET_WIDTH;

logic [A_WIDTH-1:0]    wr_addr;
logic [A_WIDTH-1:0]    rd_addr;

head_ram_data_t        wr_data;
head_ram_data_t        rd_data;
logic                  wr_en;

assign rd_addr = pdata_in_i.bucket;

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

ht_pdata_t pdata_in_d1;
logic      pdata_in_d1_valid;
logic      pdata_in_d1_ready;

ht_delay #(
  .D_WIDTH                                ( $bits( pdata_in_d1 ) ),
  .DELAY                                  ( 1                    ),
  .PIPELINE_READY                         ( 0                    )
) ht_d1 (
  .clk_i                                  ( clk_i                ),
  .rst_i                                  ( rst_i                ),

  .data_in_i                              ( pdata_in_i           ),
  .data_in_valid_i                        ( pdata_in_valid_i     ),
  .data_in_ready_o                        ( pdata_in_ready_o     ),

  .data_out_o                             ( pdata_in_d1          ),
  .data_out_valid_o                       ( pdata_in_d1_valid    ),
  .data_out_ready_i                       ( pdata_in_d1_ready    )

);

always_comb
  begin
    pdata_out_o              = pdata_in_d1;

    pdata_out_o.head_ptr     = rd_data.ptr; 
    pdata_out_o.head_ptr_val = rd_data.ptr_val;
  end

assign pdata_out_valid_o = pdata_in_d1_valid;
assign pdata_in_d1_ready = pdata_out_ready_i;


// synthesis translate_off
clocking cb @( posedge clk_i );
endclocking

task write_to_head_ptr_ram(
  input bit [BUCKET_WIDTH-1:0]   _addr,
        bit [HEAD_PTR_WIDTH-1:0] _head_ptr,
        bit                      _head_ptr_val
);
  head_ram_data_t _wr_data;

  _wr_data.ptr     = _head_ptr;
  _wr_data.ptr_val = _head_ptr_val;

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

function void print( string msg );
  $display("%08t: %m: %s", $time, msg);
endfunction

function void print_wr_head_table( );
  string msg;
  $sformat( msg, "addr = 0x%x wr_data.ptr = 0x%x wr_data.ptr_val = 0x%x", wr_addr, wr_data.ptr, wr_data.ptr_val );
  print( msg );
endfunction

initial
  begin
    forever
      begin
        @( posedge clk_i );
        if( wr_en )
          print_wr_head_table( );
      end
  end

// synthesis translate_on

endmodule
