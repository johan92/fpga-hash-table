//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

`ifndef _HT_DBG_
`define _HT_DBG_

string inst_name;

initial
  begin
    $sformat( inst_name, "%m" );
  end

function void print( string s );
  $display("%08t: %s: %s", $time, inst_name, s);
endfunction

function void print_new_task( ht_pdata_t pdata );
  print( pdata2str( pdata ) );
endfunction

function void print_ram_data( input string prefix, input bit [TABLE_ADDR_WIDTH-1:0] addr, input ram_data_t data );
  string s;
  $sformat( s, "%s: addr = 0x%x %s", prefix, addr, ram_data2str( data ) );
  print( s );
endfunction

function void print_result( input string prefix, ht_result_t result );
  string s;
  $sformat( s, "%s: %s", prefix, result2str( result ) );
  print( s );
endfunction

`endif // _HT_DBG_

