//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------
// Delete algo:
// 
//   if( no valid head_ptr )
//     DELETE_NOT_SUCCESS_NO_ENTRY
//   else
//     if( key matched )
//       begin
//         
//         clear data in addr
//         put addr to empty list 
//   
//         if( it's first data in chain ) 
//           begin
//             // update head ptr in head_table 
//             if( next_ptr is NULL )
//               head_ptr = NULL
//             else
//               head_ptr = next_ptr
//           end
//        else
//          if( it's last data in chain )
//            begin
//              set in previous chain addr next_ptr is NULL
//            end
//          else
//            // we got data in the middle of chain
//            begin
//              set in previous chain addr next_ptr is ptr of next data
//            end
//   
//         DELETE_SUCCESS
//       end
//     else
//       begin
//         DELETE_NOT_SUCCESS_NO_ENTRY
//       end


import hash_table::*;

module data_table_delete #(
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
  output  [A_WIDTH-1:0]       add_empty_ptr_o,
  output                      add_empty_ptr_en_o,

  head_table_if.master        head_table_if,
  
  ht_res_if.master            ht_res_if
);

enum int unsigned {
  IDLE_S,

  NO_VALID_HEAD_PTR_S,

  READ_HEAD_S,
  GO_ON_CHAIN_S,

  IN_TAIL_WITHOUT_MATCH_S,

  KEY_MATCH_IN_HEAD_S,
  KEY_MATCH_IN_MIDDLE_S,
  KEY_MATCH_IN_TAIL_S,

  CLEAR_RAM_AND_PTR_S

} state, next_state, state_d1;

ht_pdata_t              task_locked;
logic                   key_match;
logic                   got_tail;
logic [A_WIDTH-1:0]     rd_addr;
ram_data_t              prev_rd_data;
ram_data_t              prev_prev_rd_data;
logic [A_WIDTH-1:0]     prev_rd_addr;

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

// we need to do search, so this FSM will be similar 
// with search FSM

always_comb
  begin
    next_state = state;

    case( state )
      IDLE_S:
        begin
          if( task_valid_i && task_ready_o )
            begin
              if( task_i.head_ptr_val == 1'b0 )
                next_state = NO_VALID_HEAD_PTR_S;
              else
                next_state = READ_HEAD_S;
            end
        end

      READ_HEAD_S, GO_ON_CHAIN_S:
        begin
          if( rd_data_val )
            begin
              if( key_match )
                begin
                  if( state == READ_HEAD_S )
                    next_state = KEY_MATCH_IN_HEAD_S;
                  else
                    if( got_tail )
                      next_state = KEY_MATCH_IN_TAIL_S;
                    else
                      next_state = KEY_MATCH_IN_MIDDLE_S;
                end
              else
                if( got_tail )
                  next_state = IN_TAIL_WITHOUT_MATCH_S;
                else
                  next_state = GO_ON_CHAIN_S;
            end
        end
      
      KEY_MATCH_IN_HEAD_S, KEY_MATCH_IN_MIDDLE_S, KEY_MATCH_IN_TAIL_S:
        begin
          next_state = CLEAR_RAM_AND_PTR_S; 
        end

      CLEAR_RAM_AND_PTR_S, NO_VALID_HEAD_PTR_S, IN_TAIL_WITHOUT_MATCH_S:
        begin
          // waiting for accepting report 
          if( ht_res_if.valid && ht_res_if.ready )
            next_state = IDLE_S;
        end

      default:
        begin
          next_state = IDLE_S;
        end
    endcase
  end

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    task_locked <= '0;
  else
    if( task_ready_o && task_valid_i )
      task_locked <= task_i;

assign key_match = ( task_locked.cmd.key == data_table_if.rd_data.key );
assign got_tail  = ( data_table_if.rd_data.next_ptr_val == 1'b0  );

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    begin
      rd_addr      <= '0;
      prev_rd_addr <= '0;
    end
  else
    if( ( state == IDLE_S ) && ( next_state == READ_HEAD_S ) )
      begin
        rd_addr      <= task_i.head_ptr;
        prev_rd_addr <= rd_addr;
      end
    else
      if( rd_data_val && ( next_state == GO_ON_CHAIN_S ) )
        begin
          rd_addr      <= data_table_if.rd_data.next_ptr;
          prev_rd_addr <= rd_addr;
        end

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    rd_data_val_d1 <= 1'b0;
  else
    rd_data_val_d1 <= rd_data_val;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    begin
      prev_rd_data <= '0;
      prev_prev_rd_data <= '0;
    end
  else
    if( rd_data_val )
      begin
        prev_rd_data      <= data_table_if.rd_data;
        prev_prev_rd_data <= prev_rd_data;
      end


assign task_ready_o = ( state == IDLE_S );

assign data_table_if.rd_en      = ( state_first_tick || rd_data_val_d1 ) && ( ( state == READ_HEAD_S   ) || 
                                                                              ( state == GO_ON_CHAIN_S ) );   

assign data_table_if.rd_addr    = rd_addr; 

assign data_table_if.wr_en      = state_first_tick && ( ( state == KEY_MATCH_IN_MIDDLE_S  ) ||
                                                        ( state == KEY_MATCH_IN_TAIL_S    ) || 
                                                        ( state == CLEAR_RAM_AND_PTR_S    ) );

ram_data_t rd_data_locked;

always_ff @( posedge clk_i )
  if( rd_data_val )
    rd_data_locked <= data_table_if.rd_data;

always_comb
  begin
    data_table_if.wr_data = prev_prev_rd_data;
    data_table_if.wr_addr = 'x;

    case( state )

      CLEAR_RAM_AND_PTR_S:
        begin
          data_table_if.wr_data = '0; 

          data_table_if.wr_addr = rd_addr;
        end

      KEY_MATCH_IN_MIDDLE_S:
        begin
          data_table_if.wr_data.next_ptr     = rd_data_locked.next_ptr;
          data_table_if.wr_data.next_ptr_val = rd_data_locked.next_ptr_val;

          data_table_if.wr_addr              = prev_rd_addr;
        end
      
      KEY_MATCH_IN_TAIL_S:
        begin
          data_table_if.wr_data.next_ptr     = '0;
          data_table_if.wr_data.next_ptr_val = 1'b0;

          data_table_if.wr_addr              = prev_rd_addr;
        end

      default:
        begin
          // do nothing
          data_table_if.wr_data = prev_prev_rd_data;
          data_table_if.wr_addr = 'x;
        end
    endcase
  end

// ******* Head Ptr table magic *******
assign head_table_if.wr_addr          = task_locked.bucket; 
assign head_table_if.wr_data_ptr      = rd_data_locked.next_ptr;
assign head_table_if.wr_data_ptr_val  = rd_data_locked.next_ptr_val;
assign head_table_if.wr_en            = state_first_tick && ( state == KEY_MATCH_IN_HEAD_S );

// ******* Empty ptr storage ******

assign add_empty_ptr_o     = rd_addr;
assign add_empty_ptr_en_o  = state_first_tick && ( state == CLEAR_RAM_AND_PTR_S );

// ******* Result calculation *******
assign ht_res_if.result.cmd         = task_locked.cmd;
assign ht_res_if.result.bucket      = task_locked.bucket;
assign ht_res_if.result.found_value = '0;
assign ht_res_if.result.rescode     = ( ( state == NO_VALID_HEAD_PTR_S     ) ||
                                        ( state == IN_TAIL_WITHOUT_MATCH_S ) ) ? ( DELETE_NOT_SUCCESS_NO_ENTRY ):
                                                                                 ( DELETE_SUCCESS              );

ht_chain_state_t chain_state;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    chain_state <= NO_CHAIN;
  else
    if( state != next_state )
      begin
        case( next_state )
          NO_VALID_HEAD_PTR_S     : chain_state <= NO_CHAIN;
          IN_TAIL_WITHOUT_MATCH_S : chain_state <= IN_TAIL_NO_MATCH;
          KEY_MATCH_IN_HEAD_S     : chain_state <= IN_HEAD;
          KEY_MATCH_IN_MIDDLE_S   : chain_state <= IN_MIDDLE;
          KEY_MATCH_IN_TAIL_S     : chain_state <= IN_TAIL;
          // no default: just keep old value
        endcase
      end

assign ht_res_if.result.chain_state = chain_state; 

assign ht_res_if.valid = ( state == CLEAR_RAM_AND_PTR_S      ) ||
                         ( state == NO_VALID_HEAD_PTR_S      ) ||
                         ( state == IN_TAIL_WITHOUT_MATCH_S  );



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
