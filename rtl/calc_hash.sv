//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

import hash_table::*;

module calc_hash (

  input                    clk_i,
  input                    rst_i,

  input        ht_pdata_t  pdata_in_i,
  input                    pdata_in_valid_i,
  output                   pdata_in_ready_o,

  output       ht_pdata_t  pdata_out_o,
  output                   pdata_out_valid_o,
  input                    pdata_out_ready_i

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
            .data_i                                 ( pdata_in_i.cmd.key[31:0] ),
            .crc32_o                                ( crc32_w                  )
          );
        end
      
      // selecting high bits for bucket
      assign bucket = crc32_w[ 31 : 31 - BUCKET_WIDTH + 1 ];
    end
  
  if( HASH_TYPE == "dummy" )
    begin

      // dummy hash - just selecing high bits in key like bucket number
      // it can be really helpfull to test hashtable
      assign bucket = pdata_in_i.cmd.key[ KEY_WIDTH -1 : KEY_WIDTH - BUCKET_WIDTH ];
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

ht_pdata_t pdata_w_buck;

// just replacing bucket
always_comb
  begin
    pdata_w_buck        = pdata_in_i;
    pdata_w_buck.bucket = bucket;
  end

ht_delay #(
  .D_WIDTH                                ( $bits( pdata_out_o ) ),
  .DELAY                                  ( 1                    ),
  .PIPELINE_READY                         ( 0                    )
) ht_d1 (
  .clk_i                                  ( clk_i                ),
  .rst_i                                  ( rst_i                ),

  .data_in_i                              ( pdata_w_buck         ),
  .data_in_valid_i                        ( pdata_in_valid_i     ),
  .data_in_ready_o                        ( pdata_in_ready_o     ),

  .data_out_o                             ( pdata_out_o          ),
  .data_out_valid_o                       ( pdata_out_valid_o    ),
  .data_out_ready_i                       ( pdata_out_ready_i    )

);

endmodule
