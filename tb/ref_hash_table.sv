//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------
// Description:
// Class for "reference" hash table implementation.
// Commands executes via "do_command" function, 
// it returns ht_result_t - it should be the same like RTL result.
//-----------------------------------------------------------------------------

`ifndef _REF_HASH_TABLE_
`define _REF_HASH_TABLE_

import hash_table::*;

class ref_hash_table;
  
  int max_keys_cnt;

  typedef bit [KEY_WIDTH-1:0]   key_t;
  typedef bit [VALUE_WIDTH-1:0] value_t;
  
  value_t ass_arr[ key_t ];

  function new( int _max_keys_cnt );
    this.max_keys_cnt  = _max_keys_cnt;
  endfunction
 
  function ht_result_t do_command( input ht_command_t cmd ); 
    key_t tmp;

    ht_result_t res;
    
    res.cmd = cmd;
                              
    case( cmd.opcode )
      OP_INIT:
        begin
          if( ass_arr.first( tmp ) )
            begin
              do
                ass_arr.delete( tmp );
              while( ass_arr.next( tmp ) );
            end

          res.rescode = INIT_SUCCESS;
        end

      OP_SEARCH:
        begin
          if( ass_arr.exists( cmd.key ) )
            begin
              res.rescode     = SEARCH_FOUND;
              res.found_value = ass_arr[ cmd.key ];
            end
          else
            begin
              res.rescode = SEARCH_NOT_SUCCESS_NO_ENTRY;
            end
        end

      OP_INSERT:
        begin
          if( ass_arr.exists( cmd.key ) )
            begin
              res.rescode = INSERT_SUCCESS_SAME_KEY;
              ass_arr[ cmd.key ] = cmd.value;
            end
          else
            if( ass_arr.size() >= this.max_keys_cnt )
              begin
                res.rescode = INSERT_NOT_SUCCESS_TABLE_IS_FULL;
              end
            else
              begin
                res.rescode = INSERT_SUCCESS;
                ass_arr[ cmd.key ] = cmd.value;
              end
        end

      OP_DELETE:
        begin
          if( ass_arr.exists( cmd.key ) )
            begin
              res.rescode = DELETE_SUCCESS;
              ass_arr.delete( cmd.key );
            end
          else
            begin
              res.rescode = DELETE_NOT_SUCCESS_NO_ENTRY;
            end
        end

      default:
        begin
          $display("Unknown cmd.opcode = %s", cmd.opcode );
          $fatal;
        end
    endcase

    return res;
  endfunction                          
  
  function automatic int get_key_that_exists( output key_t key_o );
    key_t keys[$];
    
    key_t i;
    int r;
    
    if( ass_arr.size() == 0 )
      begin
        // no 
        return -1;
      end

    // getting all keys in ass_arr
    ass_arr.first( i );
    keys.push_back( i );

    while( ass_arr.next( i ) )
      begin
        keys.push_back( i );
      end
    
    keys.shuffle( );
    
    // selecting random key from list
    r = $urandom_range( keys.size() - 1, 0 );
    
    key_o = keys[r];

    // selfchecking assertion
    if( ass_arr.exists( key_o ) == 0 )
      begin
        $error("key_o = 0x%x", key_o );
      end

    return 0;
  endfunction 
endclass

`endif 
