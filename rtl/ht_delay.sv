module ht_delay #(
  // interface settings
  parameter KEY_WIDTH      = 32,
  parameter VALUE_WIDTH    = 16,
  parameter BUCKET_WIDTH   = 8,
  parameter HEAD_PTR_WIDTH = 10

  // delay ticks
  parameter DELAY          = 1,

  parameter PIPELINE_READY = 0
)
(
  input        clk_i,
  input        rst_i,

  ht_if.slave  ht_in,
  ht_if.master ht_out

);
localparam DATA_WIDTH = KEY_WIDTH    + VALUE_WIDTH    + $bits( ht_cmd_t ) + 
                        BUCKET_WIDTH + HEAD_PTR_WIDTH + 1 /*head_ptr_val width*/;

logic [DATA_WIDTH-1:0] ht_in_data;
logic [DATA_WIDTH-1:0] ht_out_data;

assign ht_in_data  = { ht_in.key, ht_in.value, ht_in.cmd, ht_in.bucket, ht_in.head_ptr, ht_in.head_ptr_val };
assign { ht_out.key, ht_out.value, ht_out.cmd, ht_out.bucket, ht_out.head_ptr, ht_out.head_ptr_val } = ht_out_data;

generate
  if( DELAY == 0 )
    begin
      assign ht_out_data  = ht_in_data;
      assign ht_out.valid = ht_in.valid;
      assign ht_in.ready  = ht_out.ready;
    end

  if( DELAY == 1 )
    begin
      altera_avalon_st_pipeline_base #( 
         .SYMBOLS_PER_BEAT                      ( 1                 ),
         .BITS_PER_SYMBOL                       ( DATA_WIDTH        ),
         .PIPELINE_READY                        ( PIPELINE_READY    )
      ) d1 (
        .clk                                    ( clk_i             ),
        .reset                                  ( rst_i             ),

        .in_ready                               ( ht_in.ready       ),
        .in_valid                               ( ht_in.valid       ),
        .in_data                                ( ht_in_data        ),

        .out_ready                              ( ht_out.ready      ),
        .out_valid                              ( ht_out.valid      ),
        .out_data                               ( ht_out_data       )
      );
    end
endgenerate

endmodule
