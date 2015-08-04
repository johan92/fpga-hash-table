import hash_table::*;

module calc_hash #(
  parameter KEY_WIDTH        = 32,
  parameter VALUE_WIDTH      = 16,
  parameter BUCKET_WIDTH     = 8,
  parameter TABLE_ADDR_WIDTH = 10,
  parameter HASH_TYPE        = "dummy"
)(

  input                    clk_i,
  input                    rst_i,
  
  ht_if.slave              ht_in,
  ht_if.master             ht_out

);

logic [BUCKET_WIDTH-1:0] bucket;

generate
  if( HASH_TYPE == "crc32" )
    begin
      logic [31:0] crc32_w;

      if( KEY_WIDTH == 32 )
        begin
          // pure combinational
          CRC32_D32 crc32_d32(
            .data_i                                 ( ht_in.key[31:0] ),
            .crc32_o                                ( crc32_w          )
          );
        end
      
      // selecting high bits for bucket
      assign bucket = crc32_w[ 31 : 31 - BUCKET_WIDTH + 1 ];
    end
  
  if( HASH_TYPE == "dummy" )
    begin

      // dummy hash - just selecing high bits in key like bucket number
      // it can be really helpfull to test hashtable
      assign bucket = ht_in.key[ KEY_WIDTH -1 : KEY_WIDTH - BUCKET_WIDTH ];
    end

  if( ( HASH_TYPE != "crc32" ) && ( HASH_TYPE != "dummy") )
    begin
      initial
        begin
          $error("ERROR %m: wrong parameter HASH_TYPE value: %s", HASH_TYPE );
          $finish();
        end
    end
endgenerate

ht_if #( 
  .KEY_WIDTH      ( KEY_WIDTH        ),
  .VALUE_WIDTH    ( VALUE_WIDTH      ),
  .BUCKET_WIDTH   ( BUCKET_WIDTH     ),
  .HEAD_PTR_WIDTH ( TABLE_ADDR_WIDTH )
) ht_w_buck ( 
  .clk         ( clk_i       ) 
);

assign ht_w_buck.key          = ht_in.key; 
assign ht_w_buck.value        = ht_in.value;
assign ht_w_buck.cmd          = ht_in.cmd;

assign ht_w_buck.bucket       = bucket;

assign ht_w_buck.head_ptr     = ht_in.head_ptr;
assign ht_w_buck.head_ptr_val = ht_in.head_ptr_val;
assign ht_w_buck.valid        = ht_in.valid;

assign ht_in.ready            = ht_w_buck.ready;

ht_delay #(
  .KEY_WIDTH                              ( KEY_WIDTH         ),
  .VALUE_WIDTH                            ( VALUE_WIDTH       ),

  .BUCKET_WIDTH                           ( BUCKET_WIDTH      ),
  .HEAD_PTR_WIDTH                         ( TABLE_ADDR_WIDTH  ),

  .DELAY                                  ( 1                 ),
  .PIPELINE_READY                         ( 0                 )
) ht_d1 (
  .clk_i                                  ( clk_i             ),
  .rst_i                                  ( rst_i             ),

  .ht_in                                  ( ht_w_buck         ),
  .ht_out                                 ( ht_out            )

);

endmodule
