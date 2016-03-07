//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

module empty_ptr_storage #(
  parameter A_WIDTH = 8
)(

  input                clk_i,
  input                rst_i,

  input                srst_i,
  
  // interface to add empty pointers
  input  [A_WIDTH-1:0] add_empty_ptr_i,
  input                add_empty_ptr_en_i,
  
  // interface to read empty pointers,
  // if val is zero - there is no more empty pointers
  input                next_empty_ptr_rd_ack_i,
  output [A_WIDTH-1:0] next_empty_ptr_o,
  output               next_empty_ptr_val_o

);

logic fifo_empty;
logic fifo_full;

ht_scfifo #(
  .DATA_W                                 ( A_WIDTH                 ),
  .ADDR_W                                 ( A_WIDTH                 )
) fifo (
  .clk_i                                  ( clk_i                   ),
  .rst_i                                  ( rst_i                   ),

  .srst_i                                 ( srst_i                  ),

  .wr_data_i                              ( add_empty_ptr_i         ),
  .wr_req_i                               ( add_empty_ptr_en_i      ),
   
  .rd_req_i                               ( next_empty_ptr_rd_ack_i ),
  .rd_data_o                              ( next_empty_ptr_o        ),
 
  .empty_o                                ( fifo_empty              ),
  .full_o                                 ( fifo_full               )
  
);

assign next_empty_ptr_val_o = !fifo_empty;

// synthesis translate_off

function void print( string msg );
  $display("%08t: %m: %s", $time, msg);
endfunction

function void print_add_empty_ptr( );
  string msg;

  if( add_empty_ptr_en_i )
    begin
      $sformat( msg, "add_empty_ptr: 0x%x", add_empty_ptr_i );
      print( msg );
    end
endfunction

function void print_get_empty_ptr( );
  string msg;

  if( next_empty_ptr_rd_ack_i )
    begin
      $sformat( msg, "get_empty_ptr: 0x%x", next_empty_ptr_o );
      print( msg );
    end
endfunction

initial
  begin
    forever
      begin
        @( posedge clk_i );
        print_add_empty_ptr( );
        print_get_empty_ptr( );
      end
  end


// synthesis translate_on

endmodule
