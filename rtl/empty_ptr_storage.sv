module empty_ptr_storage #(
  parameter A_WIDTH = 8
)(

  input                clk_i,
  input                rst_i,
  
  // interface to add empty pointers
  input  [A_WIDTH-1:0] add_empty_ptr_i,
  input                add_empty_ptr_en_i,
  
  // interface to read empty pointers,
  // if val is zero - there is no more empty pointers
  input                      next_empty_ptr_rd_ack_i,
  output logic [A_WIDTH-1:0] next_empty_ptr_o,
  output logic               next_empty_ptr_val_o

);

// NOTE: 
// now it at logic, because i'm lazy
// it should be at fifo

localparam ADDR_CNT = 2**A_WIDTH;

logic [ADDR_CNT-1:0] empty_ptr_mask;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    empty_ptr_mask <= '1;
  else
    if( next_empty_ptr_rd_ack_i && next_empty_ptr_val_o )
      empty_ptr_mask[ next_empty_ptr_o ] <= 1'b0;
    else
      if( add_empty_ptr_en_i )
        empty_ptr_mask[ add_empty_ptr_i ] <= 1'b1;

always_comb
  begin
    next_empty_ptr_o     = '0;
    next_empty_ptr_val_o = 1'b0;

    for( int i = 0; i < ADDR_CNT; i++ )
      begin
        if( empty_ptr_mask[i] )
          begin
            next_empty_ptr_o     = i[$clog2(ADDR_CNT)-1:0];
            next_empty_ptr_val_o = 1'b1;
            break;
          end
      end
  end


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
