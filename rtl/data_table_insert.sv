import hash_table::*;

module data_table_insert(

);
// ******* Insert Data logic *******

/*
Insert algo:
  if( no valid head_ptr )
    begin
      goto: get new empty addr
    end
  else
    begin
      start seaching - tring to find data with the same key
      at the end of the search we will be at tail of chain

      if( key matched )
        just update data in this addr, 
        INSERT_SUCCESS_SAME_KEY
    end

  get new empty addr:
    if( no empty addr - table is full )
      INSERT_NOT_SUCCESS_TABLE_IS_FULL
    else
      if( it was no valid head ptr ) 
        begin
          update info about head ptr in head table
          write data in addr, next_ptr is null

          INSERT_SUCCESS
        end
      // there was some data in chain, so, just adding at end of chain
      else
        begin
          write data in addr, next_ptr is null
          update ptr in previous chain addr

          INSERT_SUCCESS
        end
*/

enum int unsigned {
  INS_IDLE_S,
 
  INS_GO_ON_CHAIN_S,

  INS_KEY_MATCH_S,

  INS_NO_EMPTY_ADDR_S,

  INS_NO_HEAD_PTR_WR_HEAD_PTR_S,
  INS_NO_HEAD_PTR_WR_DATA_S,
  
  INS_ON_TAIL_WR_DATA_S,
  INS_ON_TAIL_UPD_NEXT_PTR_S

} ins_state, ins_next_state;

/*

logic       [A_WIDTH-1:0] insert_wr_addr;
logic       [A_WIDTH-1:0] insert_rd_addr;
logic                     insert_rd_en;
logic       [A_WIDTH-1:0] insert_prev_rd_addr;

ram_data_t                insert_wr_data;
logic                     insert_wr_en;

logic                     insert_en;


logic       [BUCKET_WIDTH-1:0]   ins_head_table_wr_addr;
logic       [HEAD_PTR_WIDTH-1:0] ins_head_table_wr_data_ptr;
logic                            ins_head_table_wr_data_ptr_val;
logic                            ins_head_table_wr_en;

assign insert_en = ( ht_in_d1.cmd == INSERT ) && rd_data_val;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    ins_state <= INS_IDLE_S;
  else
    if( insert_en )
      ins_state <= ins_next_state;  

always_comb
  begin
    ins_next_state = ins_state;

    case( ins_state )

      INS_IDLE_S:
        begin
          // no valid head pointer
          if( !ht_in_d1.head_ptr_val )
            begin
              // got empty addresses
              if( !insert_empty_addr_val ) 
                ins_next_state = INS_NO_EMPTY_ADDR_S;
              else
                ins_next_state = INS_NO_HEAD_PTR_WR_HEAD_PTR_S;
            end
          // got head pointer
          else
            begin
              if( key_match )
                ins_next_state = INS_KEY_MATCH_S;
              else
                begin
                  // on tail
                  if( !rd_data.next_ptr_val )
                    begin
                      if( !insert_empty_addr_val )
                        ins_next_state = INS_ON_TAIL_WR_DATA_S;
                      else
                        ins_next_state = INS_NO_EMPTY_ADDR_S;
                    end
                  else
                    begin
                      ins_next_state = INS_GO_ON_CHAIN_S;
                    end
                end
            end
        end

      INS_GO_ON_CHAIN_S:
        begin
          if( key_match )
            ins_next_state = INS_KEY_MATCH_S;
          else
            begin
              // on tail
              if( !rd_data.next_ptr_val )
                begin
                  if( !insert_empty_addr_val )
                    ins_next_state = INS_ON_TAIL_WR_DATA_S;
                  else
                    ins_next_state = INS_NO_EMPTY_ADDR_S;
                end
              else
                begin
                  ins_next_state = INS_GO_ON_CHAIN_S;
                end
            end
        end

      INS_KEY_MATCH_S:               ins_next_state = INS_IDLE_S;
      INS_NO_EMPTY_ADDR_S:           ins_next_state = INS_IDLE_S;
      INS_NO_HEAD_PTR_WR_HEAD_PTR_S: ins_next_state = INS_NO_HEAD_PTR_WR_DATA_S;
      INS_NO_HEAD_PTR_WR_DATA_S:     ins_next_state = INS_IDLE_S;
      INS_ON_TAIL_WR_DATA_S:         ins_next_state = INS_ON_TAIL_UPD_NEXT_PTR_S;
      INS_ON_TAIL_UPD_NEXT_PTR_S:    ins_next_state = INS_IDLE_S;
      default:                       ins_next_state = INS_IDLE_S;
    endcase
  end


assign insert_rd_en   = insert_en && ( ins_next_state == INS_GO_ON_CHAIN_S );   
assign insert_rd_addr = rd_data.next_ptr; 


assign insert_wr_en   = insert_en && 
                        ( ins_next_state == INS_KEY_MATCH_S            ) ||
                        ( ins_next_state == INS_NO_HEAD_PTR_WR_DATA_S  ) || 
                        ( ins_next_state == INS_ON_TAIL_WR_DATA_S      ) ||
                        ( ins_next_state == INS_ON_TAIL_UPD_NEXT_PTR_S ) ; 

always_comb
  begin
    insert_wr_data = rd_data;
    insert_wr_addr = 'x;

    case( ins_next_state )
      INS_KEY_MATCH_S:
        begin
          // just rewriting value
          insert_wr_data.value = ht_in_d1.value;

          insert_wr_addr       = rd_addr;
        end

      INS_NO_HEAD_PTR_WR_DATA_S, INS_ON_TAIL_WR_DATA_S:
        begin
          insert_wr_data.key          = ht_in_d1.key;
          insert_wr_data.value        = ht_in_d1.value;
          insert_wr_data.next_ptr     = '0;
          insert_wr_data.next_ptr_val = 1'b0;

          insert_wr_addr              = insert_empty_addr; 
        end

      INS_ON_TAIL_UPD_NEXT_PTR_S:
        begin
          insert_wr_data.next_ptr     = insert_empty_addr;
          insert_wr_data.next_ptr_val = 1'b1;

          insert_wr_addr              = insert_prev_rd_addr; 
        end
      
      default:
        begin
          // do nothing
          insert_wr_data = rd_data;
          insert_wr_addr = 'x;
        end
    endcase
  end

assign ins_head_table_wr_addr         = ht_in_d1.bucket; 
assign ins_head_table_wr_data_ptr     = insert_empty_addr; 
assign ins_head_table_wr_data_ptr_val = 1'b1;
assign ins_head_table_wr_en           = ( ins_next_state == INS_NO_HEAD_PTR_WR_HEAD_PTR_S );

assign head_table_if.wr_addr          = ins_head_table_wr_addr; 
assign head_table_if.wr_data_ptr      = ins_head_table_wr_data_ptr;     
assign head_table_if.wr_data_ptr_val  = ins_head_table_wr_data_ptr_val;
assign head_table_if.wr_en            = ins_head_table_wr_en;           

assign insert_empty_addr_rd_ack       = insert_en && ( ( ins_next_state == INS_NO_HEAD_PTR_WR_DATA_S  ) ||
                                                       ( ins_next_state == INS_ON_TAIL_UPD_NEXT_PTR_S ) );

*/
endmodule
