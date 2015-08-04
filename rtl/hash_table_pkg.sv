package hash_table;

  typedef enum int unsigned {
    SEARCH,
    INSERT,
    DELETE
  } ht_cmd_t;

  typedef enum int unsigned {
    SEARCH_FOUND,
    SEARCH_NOT_FOUND,

    INSERT_SUCCESS,
    INSERT_SUCCESS_SAME_KEY, 
    INSERT_NOT_SUCCESS_FULL,

    DELETE_SUCCESS,
    DELETE_NOT_SUCCESS_NO_ENTRY
  } ht_res_t;
  
  typedef enum int unsigned {
    READ_NO_HEAD,
    KEY_MATCH,
    KEY_NO_MATCH_HAVE_NEXT_PTR,
    GOT_TAIL
  } ht_data_table_state_t;

endpackage
