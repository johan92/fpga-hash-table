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

} state, next_state;

logic                   no_empty_addr;

ht_data_task_t          task_locked;
logic                   key_match;
logic                   got_tail;
logic [A_WIDTH-1:0]     rd_addr;

logic [RAM_LATENCY:1]   rd_en_d;
logic                   rd_data_val;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    rd_en_d <= '0;
  else
    begin
      rd_en_d[1] <= rd_en_o;

      for( int i = 2; i <= RAM_LATENCY; i++ )
        begin
          rd_en_d[ i ] <= rd_en_d[ i - 1 ];
        end
    end

// we know ram latency, so expecting data valid 
// just delaying this tick count
assign rd_data_val = rd_en_d[RAM_LATENCY];

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

assign task_ready_o = ( state == IDLE_S );

assign rd_en_o      = ( state == READ_HEAD_S ) || ( state == GO_ON_CHAIN_S );   
assign rd_addr_o    = rd_addr; 

assign wr_en_o   = ( state == KEY_MATCH_S            ) ||
                   ( state == NO_HEAD_PTR_WR_DATA_S  ) || 
                   ( state == ON_TAIL_WR_DATA_S      ) ||
                   ( state == ON_TAIL_UPD_NEXT_PTR_S ) ; 

always_comb
  begin
    wr_data_o = rd_data_i;
    wr_addr_o = 'x;

    case( state )
      KEY_MATCH_S:
        begin
          // just rewriting value
          wr_data_o.value = task_locked.value;

          wr_addr_o       = rd_addr;
        end

      NO_HEAD_PTR_WR_DATA_S, ON_TAIL_WR_DATA_S:
        begin
          wr_data_o.key          = task_locked.key;
          wr_data_o.value        = task_locked.value;
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
          wr_data_o = rd_data_i;
          wr_addr_o = 'x;
        end
    endcase
  end

assign head_table_if.wr_addr          = task_locked.bucket; 
assign head_table_if.wr_data_ptr      = empty_addr_i; 
assign head_table_if.wr_data_ptr_val  = 1'b1;
assign head_table_if.wr_en            = ( state == NO_HEAD_PTR_WR_HEAD_PTR_S );


assign empty_addr_rd_ack_o            = ( ( state == NO_HEAD_PTR_WR_DATA_S  ) ||
                                          ( state == ON_TAIL_UPD_NEXT_PTR_S ) );
always_comb
  begin
    result_o.key   = task_locked.key;
    result_o.value = task_locked.value;
    result_o.cmd   = task_locked.cmd;
  end

always_comb
  begin
    case( state )
      KEY_MATCH_S:     result_o.res = INSERT_SUCCESS_SAME_KEY;
      NO_EMPTY_ADDR_S: result_o.res = INSERT_NOT_SUCCESS_TABLE_IS_FULL;
      default:         result_o.res = INSERT_SUCCESS;
    endcase
  end

assign result_valid_o = ( state == KEY_MATCH_S            ) ||
                        ( state == NO_EMPTY_ADDR_S        ) ||
                        ( state == NO_HEAD_PTR_WR_DATA_S  ) ||
                        ( state == ON_TAIL_UPD_NEXT_PTR_S );


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
      $sformat( msg, "INSERT_TASK: key = 0x%x head_ptr = 0x%x head_ptr_val = 0x%x", 
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
      $sformat( msg, "INSERT_RES: key = 0x%x value = 0x%x cmd = %s res = %s", 
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
