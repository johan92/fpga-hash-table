// ******* Delete Data Logic *******
/*
  Delete algo:

  if( no valid head_ptr )
    DELETE_NOT_SUCCESS_NO_ENTRY
  else
    if( key matched )
      begin
        
        clear data in addr
        put addr to empty list 

        if( it's first data in chain ) 
          begin
            // update head ptr in head_table 
            if( next_ptr is NULL )
              head_ptr = NULL
            else
              head_ptr = next_ptr
          end
       else
         if( it's last data in chain )
           begin
             set in previous chain addr next_ptr is NULL
           end
         else
           // we got data in the middle of chain
           begin
             set in previous chain addr next_ptr is ptr of next data
           end

        DELETE_SUCCESS
      end
    else
      begin
        DELETE_NOT_SUCCESS_NO_ENTRY
      end
*/

import hash_table::*;

module data_table_delete #(
  parameter RAM_LATENCY = 2,

  parameter A_WIDTH     = TABLE_ADDR_WIDTH
) ( 
  input                       clk_i,
  input                       rst_i,
  
  input  ht_data_task_t       task_i,
  input                       task_valid_i,
  output                      task_ready_o,
  
  // to data RAM
  input  ram_data_t           rd_data_i,
  output logic [A_WIDTH-1:0]  rd_addr_o,
  output logic                rd_en_o,

  output logic [A_WIDTH-1:0]  wr_addr_o,
  output ram_data_t           wr_data_o,
  output logic                wr_en_o,
  
  // to empty pointer storage
  output  [A_WIDTH-1:0]       add_empty_ptr_o,
  output                      add_empty_ptr_en_o,

  head_table_if.master        head_table_if,

  // output interface with search result
  output ht_result_t          result_o,
  output logic                result_valid_o,
  input                       result_ready_i
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

ht_data_task_t          task_locked;
logic                   key_match;
logic                   got_tail;
logic [A_WIDTH-1:0]     rd_addr;
ram_data_t              prev_rd_data;
logic [A_WIDTH-1:0]     prev_rd_addr;

logic                   rd_data_val;
logic                   state_first_tick;

rd_data_val_helper #( 
  .RAM_LATENCY                          ( RAM_LATENCY  ) 
) rd_data_val_helper (
  .clk_i                                ( clk_i        ),
  .rst_i                                ( rst_i        ),

  .rd_en_i                              ( rd_en_o      ),
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
    if( task_ready_o && task_valid_i )
      task_locked <= task_i;

assign key_match = ( task_locked.key == rd_data_i.key );
assign got_tail  = ( rd_data_i.next_ptr_val == 1'b0  );

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    rd_addr <= '0;
  else
    if( ( state == IDLE_S ) && ( next_state == READ_HEAD_S ) )
      rd_addr <= task_i.head_ptr;
    else
      if( rd_data_val && ( next_state == GO_ON_CHAIN_S ) )
        rd_addr <= rd_data_i.next_ptr;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    prev_rd_data <= '0;
  else
    if( rd_data_val )
      prev_rd_data <= rd_data_i;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    prev_rd_addr <= '0;
  else
    if( rd_en_o ) //FIXME
      prev_rd_addr <= rd_addr;

assign task_ready_o = ( state == IDLE_S );

assign rd_en_o      = state_first_tick && ( ( state == READ_HEAD_S   ) || 
                                            ( state == GO_ON_CHAIN_S ) );   

assign rd_addr_o    = rd_addr; 

assign wr_en_o      = state_first_tick && ( ( state == KEY_MATCH_IN_MIDDLE_S  ) ||
                                            ( state == KEY_MATCH_IN_TAIL_S    ) || 
                                            ( state == CLEAR_RAM_AND_PTR_S    ) );

always_comb
  begin
    wr_data_o = prev_rd_data;
    wr_addr_o = 'x;

    case( state )

      CLEAR_RAM_AND_PTR_S:
        begin
          wr_data_o = '0; 

          wr_addr_o = rd_addr;
        end

      KEY_MATCH_IN_MIDDLE_S:
        begin
          wr_data_o.next_ptr     = rd_data_i.next_ptr;
          wr_data_o.next_ptr_val = rd_data_i.next_ptr_val;

          wr_addr_o              = prev_rd_addr;
        end
      
      KEY_MATCH_IN_TAIL_S:
        begin
          wr_data_o.next_ptr     = '0;
          wr_data_o.next_ptr_val = 1'b0;

          wr_addr_o              = prev_rd_addr;
        end

      default:
        begin
          // do nothing
          wr_data_o = prev_rd_data;
          wr_addr_o = 'x;
        end
    endcase
  end

// ******* Head Ptr table magic *******
assign head_table_if.wr_addr          = task_locked.bucket; 
assign head_table_if.wr_data_ptr      = rd_data_i.next_ptr;
assign head_table_if.wr_data_ptr_val  = rd_data_i.next_ptr_val;
assign head_table_if.wr_en            = state_first_tick && ( state == KEY_MATCH_IN_HEAD_S );

// ******* Empty ptr storage ******

assign add_empty_ptr_o     = rd_addr;
assign add_empty_ptr_en_o  = state_first_tick && ( state == CLEAR_RAM_AND_PTR_S );

// ******* Result calculation *******
assign result_o.key   = task_locked.key;
assign result_o.value = task_locked.value;
assign result_o.cmd   = task_locked.cmd;

assign result_o.res = ( ( state == NO_VALID_HEAD_PTR_S     ) ||
                        ( state == IN_TAIL_WITHOUT_MATCH_S ) ) ? ( DELETE_NOT_SUCCESS_NO_ENTRY ):
                                                                 ( DELETE_SUCCESS              );

assign result_valid_o = ( state == CLEAR_RAM_AND_PTR_S      ) ||
                        ( state == NO_VALID_HEAD_PTR_S      ) ||
                        ( state == IN_TAIL_WITHOUT_MATCH_S  );

// synthesis translate_off
function void print( string msg );
  $display("%08t: %m: %s", $time, msg);
endfunction

function void print_state_transition( );
  string msg;

  if( next_state != state )
    begin
      $sformat( msg, "%s -> %s", state, next_state );
      print( msg );
    end
endfunction

function void print_new_task( );
  string msg;

  if( task_valid_i && task_ready_o )
    begin
      $sformat( msg, "DELETE_TASK: key = 0x%x head_ptr = 0x%x head_ptr_val = 0x%x", 
                                   task_i.key, task_i.head_ptr, task_i.head_ptr_val );
      print( msg );
    end
endfunction

function void print_rd_data( );
  string msg;

  if( rd_data_val )
    begin
      $sformat( msg, "RD_DATA: key = 0x%x value = 0x%x next_ptr = 0x%x, next_ptr_val = 0x%x",
                               rd_data_i.key, rd_data_i.value, rd_data_i.next_ptr, rd_data_i.next_ptr_val );
      print( msg );                             
    end
endfunction

function void print_wr_data( );
  string msg;

  if( wr_en_o )
    begin
      $sformat( msg, "WR_DATA: addr = 0x%x key = 0x%x value = 0x%x next_ptr = 0x%x, next_ptr_val = 0x%x",
                               wr_addr_o, wr_data_o.key, wr_data_o.value, wr_data_o.next_ptr, wr_data_o.next_ptr_val );
      print( msg );                             
    end
endfunction

function void print_res( );
  string msg;

  if( result_valid_o && result_ready_i )
    begin
      $sformat( msg, "DELETE_RES: key = 0x%x value = 0x%x cmd = %s res = %s", 
                                  result_o.key, result_o.value, result_o.cmd, result_o.res );
      print( msg );
    end
endfunction

initial
  begin
    forever
      begin
        @( posedge clk_i );
        print_new_task( );
        print_rd_data( );
        print_wr_data( );
        print_res( );
        print_state_transition( );
      end
  end

// synthesis translate_on
                      
endmodule
