import hash_table::*;

module data_table_search #(
  parameter A_WIDTH = TABLE_ADDR_WIDTH
)
(
  input                 clk_i,
  input                 rst_i,
  
  input  ht_pdata_t     task_i,
  input                 task_valid_i,
  output                task_ready_o,
  
  input                 rd_avail_i,
  input  ram_data_t     rd_data_i, 
  input                 rd_data_val_i,

  output [A_WIDTH-1:0]  rd_addr_o,
  output                rd_en_o,
  
  output ht_result_t    result_o,
  output logic          result_valid_o,
  input                 result_ready_i

);

// ******* Search Data logic *******
/*
  Search algo:
    if( no valid head_ptr )
      SEARCH_NOT_SUCCESS_NO_ENTRY
    else
      if( key and data matched )
        SEARCH_FOUND
      else
        SEARCH_NOT_SUCCESS_NO_ENTRY
*/

ht_pdata_t              task_locked;
logic                   key_match;
logic                   got_tail;
logic [A_WIDTH-1:0]     rd_addr;
logic [VALUE_WIDTH-1:0] found_value;

enum int unsigned {
  IDLE_S,
  NO_VALID_HEAD_PTR_S,
  READ_HEAD_S,
  GO_ON_CHAIN_S,
  KEY_MATCH_S,
  ON_TAIL_WITHOUT_MATCH_S
} state, next_state;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    state <= IDLE_S;
  else
    state <= next_state;

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
          // wait for valid rd_data
          if( rd_data_val_i )
            begin
              if( key_match )
                next_state = KEY_MATCH_S;
              else
                if( got_tail )
                  next_state = ON_TAIL_WITHOUT_MATCH_S;
                else
                  // going forward on chain
                  next_state = GO_ON_CHAIN_S;
            end

        end
        
      KEY_MATCH_S, ON_TAIL_WITHOUT_MATCH_S, NO_VALID_HEAD_PTR_S:
        begin
          // waiting for report accepted
          if( result_valid_o && result_ready_i ) 
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
    if( task_valid_i && task_ready_o )
      task_locked <= task_i;

assign key_match = ( task_locked.cmd.key == rd_data_i.key );
assign got_tail  = ( rd_data_i.next_ptr_val == 1'b0  );

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    rd_addr <= '0;
  else
    if( ( state == IDLE_S ) && ( next_state == READ_HEAD_S ) )
      rd_addr <= task_i.head_ptr;
    else
      if( rd_data_val_i && ( next_state == GO_ON_CHAIN_S ) )
        rd_addr <= rd_data_i.next_ptr;

assign rd_addr_o = rd_addr;
assign rd_en_o   = rd_avail_i && ( ( state == READ_HEAD_S ) || ( state == GO_ON_CHAIN_S ) );

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    found_value <= '0;
  else
    if( rd_data_val_i && ( next_state == KEY_MATCH_S ) )
      found_value <= rd_data_i.value;


ht_chain_state_t chain_state;

logic was_rd_data_val;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    was_rd_data_val <= 1'b0;
  else
    if( state == IDLE_S )
      was_rd_data_val <= 1'b0;
    else
      if( rd_data_val_i )
        was_rd_data_val <= 1'b1;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    chain_state <= NO_CHAIN;
  else
    if( next_state != state )
      begin
        case( next_state )
          NO_VALID_HEAD_PTR_S     : chain_state <= NO_CHAIN;
          ON_TAIL_WITHOUT_MATCH_S : chain_state <= IN_TAIL_NO_MATCH;
          
          KEY_MATCH_S             : chain_state <= ( got_tail == 1'b0 ) ? ( IN_MIDDLE ) : 
                                                                          ( ( was_rd_data_val ) ? ( IN_TAIL ) : IN_HEAD );
                                            
          // no default: just keep old value
        endcase
      end

always_comb
  begin
    result_o.cmd         = task_locked.cmd;
    result_o.bucket      = task_locked.bucket;

    result_o.found_value = found_value;
    result_o.chain_state = chain_state;
    result_o.rescode     = ( state == KEY_MATCH_S ) ? ( SEARCH_FOUND                ):
                                                      ( SEARCH_NOT_SUCCESS_NO_ENTRY );
  end

assign result_valid_o   = ( state == KEY_MATCH_S             ) ||
                          ( state == ON_TAIL_WITHOUT_MATCH_S ) ||
                          ( state == NO_VALID_HEAD_PTR_S     );

assign task_ready_o = ( state == IDLE_S );

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
    if( rd_en_o )
      rd_addr_latched <= rd_addr_o;
  end

always_ff @( posedge clk_i )
  begin
    if( task_valid_i && task_ready_o )
      print_new_task( task_i );
    
    if( rd_data_val_i )
      print_ram_data( "RD_DATA", rd_addr_latched, rd_data_i );

    if( result_valid_o && result_ready_i )
      print_result( "SEARCH_RES", result_o );

    print_state_transition( );
  end

// synthesis translate_on

endmodule
