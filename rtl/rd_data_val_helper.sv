//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

module rd_data_val_helper #( 
  parameter RAM_LATENCY = 2 
) (
  input  clk_i,
  input  rst_i,

  input  rd_en_i,
  output rd_data_val_o

);

logic [RAM_LATENCY:1]   rd_en_d;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    rd_en_d <= '0;
  else
    begin
      rd_en_d[1] <= rd_en_i;

      for( int i = 2; i <= RAM_LATENCY; i++ )
        begin
          rd_en_d[ i ] <= rd_en_d[ i - 1 ];
        end
    end

// we know ram latency, so expecting data valid 
// just delaying this tick count
assign rd_data_val_o = rd_en_d[RAM_LATENCY];

endmodule
