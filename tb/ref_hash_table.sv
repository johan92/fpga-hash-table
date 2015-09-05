/*
  Class for "reference" hash table implementation.
  Commands executes via "do_command" function, 
  it returns ht_result_t - it should be the same like RTL result.
*/

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
    
    ht_result_t res;
    
    res.cmd = cmd;
                              
    case( cmd.opcode )
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

endclass

`endif 
