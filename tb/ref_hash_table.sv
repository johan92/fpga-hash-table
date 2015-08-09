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
  
  function ht_result_t do_task( input bit [KEY_WIDTH-1:0]   key, 
                                      bit [VALUE_WIDTH-1:0] value,
                                      ht_cmd_t              cmd );
    
    ht_result_t task_res;

    task_res.key    = key;
    task_res.value  = value;
    task_res.cmd    = cmd;
                              
    case( cmd )
      SEARCH:
        begin
          if( ass_arr.exists( key ) )
            begin
              task_res.res   = SEARCH_FOUND;
              task_res.value = ass_arr[ key ];
            end
          else
            begin
              task_res.res = SEARCH_NOT_SUCCESS_NO_ENTRY;
            end
        end

      INSERT:
        begin
          if( ass_arr.exists( key ) )
            begin
              task_res.res = INSERT_SUCCESS_SAME_KEY;
              ass_arr[ key ] = value;
            end
          else
            if( ass_arr.size() >= this.max_keys_cnt )
              begin
                task_res.res = INSERT_NOT_SUCCESS_TABLE_IS_FULL;
              end
            else
              begin
                task_res.res = INSERT_SUCCESS;
                ass_arr[ key ] = value;
              end
        end

      DELETE:
        begin
          if( ass_arr.exists( key ) )
            begin
              task_res.res = DELETE_SUCCESS;
              ass_arr.delete( key );
            end
          else
            begin
              task_res.res = DELETE_NOT_SUCCESS_NO_ENTRY;
            end
        end

      default:
        begin
          $display("Unknown cmd = %s", cmd );
          $fatal;
        end
    endcase

    return task_res;
  endfunction                          


endclass

`endif 
