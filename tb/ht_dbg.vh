`ifndef _HT_DBG_
`define _HT_DBG_

function void print( string s );
  $display("%08t: %m: %s", $time, s);
endfunction

function string pdata2str( input ht_pdata_t pdata );
  string s;

  $sformat( s, "opcode = %s key = 0x%x value = 0x%x head_ptr = 0x%x head_ptr_val = 0x%x", 
                pdata.cmd.opcode, pdata.cmd.key, pdata.cmd.value, pdata.head_ptr, pdata.head_ptr_val );
  
  return s;
endfunction

function void print_new_task( ht_pdata_t pdata );
  print( pdata2str( pdata ) );
endfunction

function string ram_data2str( input ram_data_t data );
  string s;

  $sformat( s, "key = 0x%x value = 0x%x next_ptr = 0x%x, next_ptr_val = 0x%x",
                  data.key, data.value, data.next_ptr, data.next_ptr_val );

  return s;
endfunction

function void print_ram_data( input string prefix, input bit [TABLE_ADDR_WIDTH-1:0] addr, input ram_data_t data );
  string s;
  $sformat( s, "%s: addr = 0x%x %s", prefix, addr, ram_data2str( data ) );
  print( s );
endfunction

function string result2str( input ht_result_t result );
  string s;
  case( result.cmd.opcode )
    OP_SEARCH:
      $sformat( s, "key = 0x%x value = 0x%x rescode = %s", 
                    result.cmd.key, result.found_value, result.rescode );
    OP_INSERT, OP_DELETE:
      $sformat( s, "key = 0x%x value = 0x%x rescode = %s", 
                    result.cmd.key, result.cmd.value, result.rescode );
  endcase
  
  return s;
endfunction

function void print_result( input string prefix, ht_result_t result );
  string s;
  $sformat( s, "%s: %s", prefix, result2str( result ) );
  print( s );
endfunction

`endif // _HT_DBG_

