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
  input  ram_data_t           rd_data_i,
  output logic [A_WIDTH-1:0]  rd_addr_o,
  output logic                rd_en_o,

  output logic [A_WIDTH-1:0]  wr_addr_o,
  output ram_data_t           wr_data_o,
  output logic                wr_en_o,
  
  // to empty pointer storage
  input  [A_WIDTH-1:0]        empty_addr_i,
  input                       empty_addr_val_i,
  output logic                empty_addr_rd_ack_o,                 

  head_table_if.master        head_table_if,

  // output interface with search result
  output ht_result_t          result_o,
  output logic                result_valid_o,
  input                       result_ready_i
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
          if( result_valid_o && result_ready_i )
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
assign key_match = ( task_locked.cmd.key == rd_data_i.key );
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
    rd_data_val_d1 <= 1'b0;
  else
    rd_data_val_d1 <= rd_data_val;


assign task_ready_o = ( state == IDLE_S );

assign rd_en_o      = ( state_first_tick || rd_data_val_d1 ) && ( ( state == READ_HEAD_S   ) || 
                                                                  ( state == GO_ON_CHAIN_S ) );   
assign rd_addr_o    = rd_addr; 

assign wr_en_o      = state_first_tick && ( ( state == KEY_MATCH_S            ) ||
                                            ( state == NO_HEAD_PTR_WR_DATA_S  ) || 
                                            ( state == ON_TAIL_WR_DATA_S      ) ||
                                            ( state == ON_TAIL_UPD_NEXT_PTR_S ) ); 

ram_data_t rd_data_locked;

always_ff @( posedge clk_i )
  if( rd_data_val )
    rd_data_locked <= rd_data_i;


always_comb
  begin
    wr_data_o = rd_data_locked;
    wr_addr_o = 'x;

    case( state )
      KEY_MATCH_S:
        begin
          // just rewriting value
          wr_data_o.value = task_locked.cmd.value;

          wr_addr_o       = rd_addr;
        end

      NO_HEAD_PTR_WR_DATA_S, ON_TAIL_WR_DATA_S:
        begin
          wr_data_o.key          = task_locked.cmd.key;
          wr_data_o.value        = task_locked.cmd.value;
          wr_data_o.next_ptr     = '0;
          wr_data_o.next_ptr_val = 1'b0;

          wr_addr_o              = empty_addr_i; 
        end

      ON_TAIL_UPD_NEXT_PTR_S:
        begin
          wr_data_o.next_ptr     = empty_addr_i;
          wr_data_o.next_ptr_val = 1'b1;

          wr_addr_o              = rd_addr; 
        end
      
      default:
        begin
          // do nothing
          wr_data_o = rd_data_locked;
          wr_addr_o = 'x;
        end
    endcase
  end

assign head_table_if.wr_addr          = task_locked.bucket; 
assign head_table_if.wr_data_ptr      = empty_addr_i; 
assign head_table_if.wr_data_ptr_val  = 1'b1;
assign head_table_if.wr_en            = state_first_tick && ( state == NO_HEAD_PTR_WR_HEAD_PTR_S );


assign empty_addr_rd_ack_o            = state_first_tick && ( ( state == NO_HEAD_PTR_WR_DATA_S  ) ||
                                                              ( state == ON_TAIL_UPD_NEXT_PTR_S ) );
always_comb
  begin
    result_o.cmd         = task_locked.cmd;
    result_o.bucket      = task_locked.bucket;
    result_o.found_value = '0;

    case( state )
      KEY_MATCH_S:     result_o.rescode = INSERT_SUCCESS_SAME_KEY;
      NO_EMPTY_ADDR_S: result_o.rescode = INSERT_NOT_SUCCESS_TABLE_IS_FULL;
      default:         result_o.rescode = INSERT_SUCCESS;
    endcase
  end

assign result_valid_o = ( state == KEY_MATCH_S            ) ||
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
    if( rd_en_o )
      rd_addr_latched <= rd_addr_o;
  end

always_ff @( posedge clk_i )
  begin
    if( task_valid_i && task_ready_o )
      print_new_task( task_i );
    
    if( rd_data_val )
      print_ram_data( "RD_DATA", rd_addr_latched, rd_data_i );

    if( wr_en_o )
      print_ram_data( "WR_DATA", wr_addr_o, wr_data_o );
    
    if( result_valid_o && result_ready_i )
      print_result( "INSERT_RES", result_o );

    print_state_transition( );
  end

// synthesis translate_on

endmodule
