package hash_table;
  
  parameter KEY_WIDTH        = 32;
  parameter VALUE_WIDTH      = 16;
  parameter BUCKET_WIDTH     = 8;
  parameter HASH_TYPE        = "dummy";
  parameter TABLE_ADDR_WIDTH = 10;
  parameter HEAD_PTR_WIDTH   = TABLE_ADDR_WIDTH;

  typedef enum logic [1:0] {
    OP_SEARCH,
    OP_INSERT,
    OP_DELETE
  } ht_opcode_t;

  typedef enum int unsigned {
    SEARCH_FOUND,
    SEARCH_NOT_SUCCESS_NO_ENTRY,

    INSERT_SUCCESS,
    INSERT_SUCCESS_SAME_KEY, 
    INSERT_NOT_SUCCESS_TABLE_IS_FULL,

    DELETE_SUCCESS,
    DELETE_NOT_SUCCESS_NO_ENTRY
  } ht_rescode_t;
  
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

endpackage
