//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

import hash_table::*;

module empty_ptr_storage (
  input                      clk_i,
  input                      rst_i,
 
  // eps - empty ptr storage ^__^
  empty_ptr_storage_if.slave eps_if

);

localparam A_WIDTH = hash_table::TABLE_ADDR_WIDTH;

logic fifo_empty;
logic fifo_full;

ht_scfifo #(
  .DATA_W                                 ( A_WIDTH                      ),
  .ADDR_W                                 ( A_WIDTH                      )
) fifo (
  .clk_i                                  ( clk_i                        ),
  .rst_i                                  ( rst_i                        ),

  .srst_i                                 ( eps_if.srst                  ),

  .wr_data_i                              ( eps_if.add_empty_ptr         ),
  .wr_req_i                               ( eps_if.add_empty_ptr_en      ),
   
  .rd_req_i                               ( eps_if.next_empty_ptr_rd_ack ),
  .rd_data_o                              ( eps_if.next_empty_ptr        ),
 
  .empty_o                                ( fifo_empty                   ),
  .full_o                                 ( fifo_full                    )
  
);

assign eps_if.next_empty_ptr_val = !fifo_empty;

// synthesis translate_off
`include "../tb/ht_dbg.vh"

function void print_add_empty_ptr( );
  string msg;

  if( eps_if.add_empty_ptr_en )
    begin
      $sformat( msg, "add_empty_ptr: 0x%x", eps_if.add_empty_ptr );
      print( msg );
    end
endfunction

function void print_get_empty_ptr( );
  string msg;

  if( eps_if.next_empty_ptr_rd_ack )
    begin
      $sformat( msg, "get_empty_ptr: 0x%x", eps_if.next_empty_ptr );
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
