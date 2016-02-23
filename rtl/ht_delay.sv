//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

module ht_delay #(
  parameter D_WIDTH        = 32,

  // delay ticks
  parameter DELAY          = 1,

  parameter PIPELINE_READY = 0

)
(
  input                 clk_i,
  input                 rst_i,

  input   [D_WIDTH-1:0] data_in_i,
  input                 data_in_valid_i,
  output                data_in_ready_o,

  output  [D_WIDTH-1:0] data_out_o,
  output                data_out_valid_o,
  input                 data_out_ready_i

);
generate
  if( DELAY == 0 )
    begin
      assign data_out_o        = data_in_i;
      assign data_out_valid_o  = data_in_valid_i;
      assign data_in_ready_o   = data_out_ready_i;
    end

  if( DELAY == 1 )
    begin
      altera_avalon_st_pipeline_base #( 
         .SYMBOLS_PER_BEAT                      ( 1                 ),
         .BITS_PER_SYMBOL                       ( D_WIDTH           ),
         .PIPELINE_READY                        ( PIPELINE_READY    )
      ) d1 (
        .clk                                    ( clk_i             ),
        .reset                                  ( rst_i             ),

        .in_ready                               ( data_in_ready_o   ),
        .in_valid                               ( data_in_valid_i   ),
        .in_data                                ( data_in_i         ),

        .out_ready                              ( data_out_ready_i  ),
        .out_valid                              ( data_out_valid_o  ),
        .out_data                               ( data_out_o        )
      );
    end
endgenerate

endmodule
