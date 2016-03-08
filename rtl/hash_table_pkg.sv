//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

package hash_table;
  
  parameter KEY_WIDTH        = 32;
  parameter VALUE_WIDTH      = 16;
  parameter BUCKET_WIDTH     = 8;
  parameter HASH_TYPE        = "dummy";
  parameter TABLE_ADDR_WIDTH = 10;
  parameter HEAD_PTR_WIDTH   = TABLE_ADDR_WIDTH;

  typedef enum logic [1:0] {
    OP_INIT,     // init/clear/reset ALL hash table
    OP_SEARCH,
    OP_INSERT,
    OP_DELETE
  } ht_opcode_t;

  parameter OPCODE_CNT = OP_DELETE + 1;

  typedef enum int unsigned {
    INIT_SUCCESS,

    SEARCH_FOUND,
    SEARCH_NOT_SUCCESS_NO_ENTRY,

    INSERT_SUCCESS,
    INSERT_SUCCESS_SAME_KEY, 
    INSERT_NOT_SUCCESS_TABLE_IS_FULL,

    DELETE_SUCCESS,
    DELETE_NOT_SUCCESS_NO_ENTRY
  } ht_rescode_t;

  parameter RESCODE_CNT = DELETE_NOT_SUCCESS_NO_ENTRY + 1;
  
  typedef enum int unsigned {
    READ_NO_HEAD,
    KEY_MATCH,
    KEY_NO_MATCH_HAVE_NEXT_PTR,
    GOT_TAIL
  } ht_data_table_state_t;
  
  typedef enum int unsigned {
    NO_CHAIN,

    IN_HEAD,
    IN_MIDDLE,
    IN_TAIL,

    IN_TAIL_NO_MATCH
  } ht_chain_state_t;

  typedef struct packed {
    logic [HEAD_PTR_WIDTH-1:0] ptr;
    logic                      ptr_val;
  } head_ram_data_t;

  typedef struct packed {
    logic [KEY_WIDTH-1:0]      key;
    logic [VALUE_WIDTH-1:0]    value;
    logic [HEAD_PTR_WIDTH-1:0] next_ptr;
    logic                      next_ptr_val;
  } ram_data_t; 
  
  typedef struct packed {
    logic        [KEY_WIDTH-1:0]    key;
    logic        [VALUE_WIDTH-1:0]  value;
    ht_opcode_t                     opcode;
  } ht_command_t;
  
  // pdata - data to pipeline/proccessing
  typedef struct packed {
    ht_command_t                cmd;

    logic  [BUCKET_WIDTH-1:0]   bucket;

    logic  [HEAD_PTR_WIDTH-1:0] head_ptr;
    logic                       head_ptr_val;
  } ht_pdata_t;

  typedef struct packed {
    ht_command_t                cmd;
    ht_rescode_t                rescode;
    
    logic  [BUCKET_WIDTH-1:0]   bucket;

    // valid only for opcode = OP_SEARCH
    logic [VALUE_WIDTH-1:0]     found_value;       
    
    // only for verification
    ht_chain_state_t            chain_state;
  } ht_result_t;

  function string pdata2str( input ht_pdata_t pdata );
    string s;

    $sformat( s, "opcode = %s key = 0x%x value = 0x%x head_ptr = 0x%x head_ptr_val = 0x%x", 
                  pdata.cmd.opcode, pdata.cmd.key, pdata.cmd.value, pdata.head_ptr, pdata.head_ptr_val );
    
    return s;
  endfunction

  function string ram_data2str( input ram_data_t data );
    string s;

    $sformat( s, "key = 0x%x value = 0x%x next_ptr = 0x%x next_ptr_val = 0x%x",
                    data.key, data.value, data.next_ptr, data.next_ptr_val );

    return s;
  endfunction

  function string result2str( input ht_result_t result );
    string s;

    case( result.cmd.opcode )
      OP_INIT:
        $sformat( s, "rescode = %s", result.rescode );

      OP_SEARCH:
        $sformat( s, "key = 0x%x value = 0x%x rescode = %s chain_state = %s", 
                      result.cmd.key, result.found_value, result.rescode, result.chain_state );
      OP_INSERT, OP_DELETE:
        $sformat( s, "key = 0x%x value = 0x%x rescode = %s chain_state = %s", 
                      result.cmd.key, result.cmd.value, result.rescode, result.chain_state );
      default:
        begin
          s = "";
          $error( "Unknown opcode [%s]!", result.cmd.opcode );
        end
    endcase
    
    return s;
  endfunction

endpackage
