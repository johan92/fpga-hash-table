import hash_table::*;

module data_table #( 
  parameter KEY_WIDTH        = 32,
  parameter VALUE_WIDTH      = 16,
  parameter BUCKET_WIDTH     = 8,
  parameter TABLE_ADDR_WIDTH = 10
)
(
  input                clk_i,
  input                rst_i,

  ht_if.slave          ht_in,
  ht_res_if.master     ht_res_out,
  
  head_table_if.master head_table_if,

  // interface to clear [fill with zero] all ram content
  input                clear_ram_run_i,
  output logic         clear_ram_done_o

);
localparam HEAD_PTR_WIDTH = TABLE_ADDR_WIDTH;

ht_if #( 
  .KEY_WIDTH      ( KEY_WIDTH      ),
  .VALUE_WIDTH    ( VALUE_WIDTH    ),
  .BUCKET_WIDTH   ( BUCKET_WIDTH   ),
  .HEAD_PTR_WIDTH ( HEAD_PTR_WIDTH )
) ht_in_d1 ( 
  .clk            ( clk_i          ) 
);

typedef struct packed {
  logic [KEY_WIDTH-1:0]      key;
  logic [VALUE_WIDTH-1:0]    value;
  logic [HEAD_PTR_WIDTH-1:0] next_ptr;
  logic                      next_ptr_val;
} ram_data_t; 

localparam D_WIDTH = $bits( ram_data_t );
localparam A_WIDTH = HEAD_PTR_WIDTH;

logic [A_WIDTH-1:0]    wr_addr;
logic [A_WIDTH-1:0]    rd_addr;

ram_data_t             wr_data;
ram_data_t             rd_data;
logic                  wr_en;

// flag for reading from pipelined stage
logic                  back_read;

logic                  rd_en;
logic                  rd_data_val;

assign rd_addr = back_read ? ( rd_data.next_ptr ) : ( ht_in.head_ptr );

assign rd_en   = back_read || ( ht_in.ready && ht_in.valid );

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    rd_data_val <= 1'b0;
  else
    rd_data_val <= rd_en;

logic key_match;

assign key_match = ( rd_data.key == ht_in_d1.key );

ht_data_table_state_t state;
ht_data_table_state_t next_state;

always_comb
  begin
    next_state = state;

    // no head on this bucket
    if( !ht_in_d1.head_ptr_val )
      begin
        next_state = READ_NO_HEAD;
      end
    else
      if( key_match )
        begin
          next_state = KEY_MATCH;
        end
      else
        if( !key_match && rd_data.next_ptr_val )
          begin
            next_state = KEY_NO_MATCH_HAVE_NEXT_PTR;
          end
        else
          begin
            next_state = GOT_TAIL;
          end
  end

assign back_read = ( next_state == KEY_NO_MATCH_HAVE_NEXT_PTR );

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

assign wr_addr          = ( clear_ram_flag ) ? ( clear_addr ) : ( 'x ); //FIXME
assign wr_data          = ( clear_ram_flag ) ? ( '0         ) : ( 'x );
assign wr_en            = ( clear_ram_flag ) ? ( 1'b1       ) : ( 'x ); 
assign clear_ram_done_o = clear_ram_flag && ( clear_addr == '1 );


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

true_dual_port_ram_single_clock #( 
  .DATA_WIDTH                             ( D_WIDTH           ), 
  .ADDR_WIDTH                             ( A_WIDTH           ), 
  .REGISTER_OUT                           ( 0                 )
) data_ram (
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

endmodule
