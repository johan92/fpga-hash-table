//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------
// Insert algo:
//   if( no valid head_ptr )
//     begin
//       goto: get new empty addr
//     end
//   else
//     begin
//       start seaching - tring to find data with the same key
//       at the end of the search we will be at tail of chain
//  
//       if( key matched )
//         just update data in this addr, 
//         INSERT_SUCCESS_SAME_KEY
//     end
//  
//   get new empty addr:
//     if( no empty addr - table is full )
//       INSERT_NOT_SUCCESS_TABLE_IS_FULL
//     else
//       if( it was no valid head ptr ) 
//         begin
//           update info about head ptr in head table
//           write data in addr, next_ptr is null
//  
//           INSERT_SUCCESS
//         end
//       // there was some data in chain, so, just adding at end of chain
//       else
//         begin
//           write data in addr, next_ptr is null
//           update ptr in previous chain addr
//  
//           INSERT_SUCCESS
//         end

import hash_table::*;

module data_table_insert #(
  parameter RAM_LATENCY = 2,
  parameter A_WIDTH     = TABLE_ADDR_WIDTH
) (
  input                       clk_i,
  input                       rst_i,
  
  input  ht_pdata_t           task_i,
  input                       task_valid_i,
  output                      task_ready_o,
  
  // to data RAM
  data_table_if.master        data_table_if,
  
  // to empty pointer storage
  input  [A_WIDTH-1:0]        empty_addr_i,
  input                       empty_addr_val_i,
  output logic                empty_addr_rd_ack_o,                 

  head_table_if.master        head_table_if,

  // output interface with search result
  ht_res_if.master            ht_res_if
);

enum int unsigned {
  IDLE_S,
  
  READ_HEAD_S,

  GO_ON_CHAIN_S,

  KEY_MATCH_S,

  NO_EMPTY_ADDR_S,

  NO_HEAD_PTR_WR_HEAD_PTR_S,
  NO_HEAD_PTR_WR_DATA_S,
  
  ON_TAIL_WR_DATA_S,
  ON_TAIL_UPD_NEXT_PTR_S

} state, next_state, state_d1;

logic                   no_empty_addr;

ht_pdata_t              task_locked;
logic                   key_match;
logic                   got_tail;
logic [A_WIDTH-1:0]     rd_addr;

logic                   rd_data_val;
logic                   rd_data_val_d1;
logic                   state_first_tick;

rd_data_val_helper #( 
  .RAM_LATENCY                          ( RAM_LATENCY  ) 
) rd_data_val_helper (
  .clk_i                                ( clk_i        ),
  .rst_i                                ( rst_i        ),

  .rd_en_i                              ( data_table_if.rd_en      ),
  .rd_data_val_o                        ( rd_data_val  )

);

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    state <= IDLE_S;
  else
    state <= next_state; 

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    state_d1 <= IDLE_S;
  else
    state_d1 <= state;

assign state_first_tick = ( state != state_d1 );

always_comb
  begin
    next_state = state;

    case( state )

      IDLE_S:
        begin
          if( task_valid_i && task_ready_o )
            begin
              // no valid head pointer
              if( !task_i.head_ptr_val )
                begin
                  next_state = ( no_empty_addr ) ? ( NO_EMPTY_ADDR_S           ):
                                                   ( NO_HEAD_PTR_WR_HEAD_PTR_S );
                end
              else
                begin
                  next_state = READ_HEAD_S;
                end
            end
        end

      READ_HEAD_S, GO_ON_CHAIN_S:
        begin
          if( rd_data_val )
            begin
              if( key_match )
                next_state = KEY_MATCH_S;
              else
                begin
                  // on tail
                  if( got_tail )
                    begin
                      next_state = ( no_empty_addr ) ? ( NO_EMPTY_ADDR_S   ):
                                                       ( ON_TAIL_WR_DATA_S );
                    end
                  else
                    begin
                      next_state = GO_ON_CHAIN_S;
                    end
                end
            end
        end

      KEY_MATCH_S, NO_EMPTY_ADDR_S, NO_HEAD_PTR_WR_DATA_S, ON_TAIL_UPD_NEXT_PTR_S: 
        begin
          if( ht_res_if.valid && ht_res_if.ready )
            begin
              next_state = IDLE_S;
            end
        end
      
      NO_HEAD_PTR_WR_HEAD_PTR_S: next_state = NO_HEAD_PTR_WR_DATA_S;
      ON_TAIL_WR_DATA_S:         next_state = ON_TAIL_UPD_NEXT_PTR_S;

      default: next_state = IDLE_S;
    endcase
  end

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    task_locked <= '0;
  else
    if( task_ready_o && task_valid_i )
      task_locked <= task_i;

assign no_empty_addr = !empty_addr_val_i;
assign key_match = ( task_locked.cmd.key == data_table_if.rd_data.key );
assign got_tail  = ( data_table_if.rd_data.next_ptr_val == 1'b0  );

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    rd_addr <= '0;
  else
    if( ( state == IDLE_S ) && ( next_state == READ_HEAD_S ) )
      rd_addr <= task_i.head_ptr;
    else
      if( rd_data_val && ( next_state == GO_ON_CHAIN_S ) )
        rd_addr <= data_table_if.rd_data.next_ptr;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    rd_data_val_d1 <= 1'b0;
  else
    rd_data_val_d1 <= rd_data_val;


assign task_ready_o = ( state == IDLE_S );

assign data_table_if.rd_en      = ( state_first_tick || rd_data_val_d1 ) && ( ( state == READ_HEAD_S   ) || 
                                                                  ( state == GO_ON_CHAIN_S ) );   
assign data_table_if.rd_addr    = rd_addr; 

assign data_table_if.wr_en      = state_first_tick && ( ( state == KEY_MATCH_S            ) ||
                                                        ( state == NO_HEAD_PTR_WR_DATA_S  ) || 
                                                        ( state == ON_TAIL_WR_DATA_S      ) ||
                                                        ( state == ON_TAIL_UPD_NEXT_PTR_S ) ); 

ram_data_t rd_data_locked;

always_ff @( posedge clk_i )
  if( rd_data_val )
    rd_data_locked <= data_table_if.rd_data;


always_comb
  begin
    data_table_if.wr_data = rd_data_locked;
    data_table_if.wr_addr = 'x;

    case( state )
      KEY_MATCH_S:
        begin
          // just rewriting value
          data_table_if.wr_data.value = task_locked.cmd.value;

          data_table_if.wr_addr       = rd_addr;
        end

      NO_HEAD_PTR_WR_DATA_S, ON_TAIL_WR_DATA_S:
        begin
          data_table_if.wr_data.key          = task_locked.cmd.key;
          data_table_if.wr_data.value        = task_locked.cmd.value;
          data_table_if.wr_data.next_ptr     = '0;
          data_table_if.wr_data.next_ptr_val = 1'b0;

          data_table_if.wr_addr              = empty_addr_i; 
        end

      ON_TAIL_UPD_NEXT_PTR_S:
        begin
          data_table_if.wr_data.next_ptr     = empty_addr_i;
          data_table_if.wr_data.next_ptr_val = 1'b1;

          data_table_if.wr_addr              = rd_addr; 
        end
      
      default:
        begin
          // do nothing
          data_table_if.wr_data = rd_data_locked;
          data_table_if.wr_addr = 'x;
        end
    endcase
  end

assign head_table_if.wr_addr          = task_locked.bucket; 
assign head_table_if.wr_data.ptr      = empty_addr_i; 
assign head_table_if.wr_data.ptr_val  = 1'b1;
assign head_table_if.wr_en            = state_first_tick && ( state == NO_HEAD_PTR_WR_HEAD_PTR_S );


assign empty_addr_rd_ack_o            = state_first_tick && ( ( state == NO_HEAD_PTR_WR_DATA_S  ) ||
                                                              ( state == ON_TAIL_UPD_NEXT_PTR_S ) );


ht_chain_state_t chain_state;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    chain_state <= NO_CHAIN;
  else
    if( next_state != state )
      begin
        case( next_state )
          NO_EMPTY_ADDR_S           : chain_state <= NO_CHAIN;
          NO_HEAD_PTR_WR_HEAD_PTR_S : chain_state <= IN_HEAD;
          ON_TAIL_WR_DATA_S         : chain_state <= IN_TAIL;
          // no default: just keep old value
        endcase
      end


always_comb
  begin
    ht_res_if.result.cmd         = task_locked.cmd;
    ht_res_if.result.bucket      = task_locked.bucket;
    ht_res_if.result.found_value = '0;
    ht_res_if.result.chain_state = chain_state;

    case( state )
      KEY_MATCH_S:     ht_res_if.result.rescode = INSERT_SUCCESS_SAME_KEY;
      NO_EMPTY_ADDR_S: ht_res_if.result.rescode = INSERT_NOT_SUCCESS_TABLE_IS_FULL;
      default:         ht_res_if.result.rescode = INSERT_SUCCESS;
    endcase
  end



assign ht_res_if.valid = ( state == KEY_MATCH_S            ) ||
                        ( state == NO_EMPTY_ADDR_S        ) ||
                        ( state == NO_HEAD_PTR_WR_DATA_S  ) ||
                        ( state == ON_TAIL_UPD_NEXT_PTR_S );


// synthesis translate_off
`include "../tb/ht_dbg.vh"

function void print_state_transition( );
  string msg;

  if( next_state != state )
    begin
      $sformat( msg, "%s -> %s", state, next_state );
      print( msg );
    end
endfunction

logic [A_WIDTH-1:0] rd_addr_latched;

always_latch
  begin
    if( data_table_if.rd_en )
      rd_addr_latched <= data_table_if.rd_addr;
  end

always_ff @( posedge clk_i )
  begin
    if( task_valid_i && task_ready_o )
      print_new_task( task_i );
    
    if( rd_data_val )
      print_ram_data( "RD", rd_addr_latched, data_table_if.rd_data );

    if( data_table_if.wr_en )
      print_ram_data( "WR", data_table_if.wr_addr, data_table_if.wr_data );
    
    if( ht_res_if.valid && ht_res_if.ready )
      print_result( "RES", ht_res_if.result );

    print_state_transition( );
  end

// synthesis translate_on

endmodule
