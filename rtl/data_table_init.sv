//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

import hash_table::*;

module data_table_init #(
  parameter A_WIDTH = TABLE_ADDR_WIDTH
) (
  input                       clk_i,
  input                       rst_i,

  input  ht_pdata_t           task_i,
  input                       task_valid_i,
  output                      task_ready_o,
  
  data_table_if.master        data_table_if,

  head_table_if.master        head_table_if,
  
  // to empty pointer storage
  output                      empty_ptr_storage_srst_o,
  output  [A_WIDTH-1:0]       add_empty_ptr_o,
  output                      add_empty_ptr_en_o,
  
  // output interface with search result
  output ht_result_t          result_o,
  output logic                result_valid_o,
  input                       result_ready_i

);

enum int unsigned {
  IDLE_S,
  RESET_EMPTY_PTR_STORAGE_S,
  INIT_RAMS_S,
  DO_REPORT_S
} state, next_state, state_d1;

ht_pdata_t        task_locked;
logic             head_table_init_done;
logic             data_table_init_done;

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

always_comb
  begin
    next_state = state;

    case( state )
      IDLE_S:
        begin
          if( task_valid_i && task_ready_o )
            begin
              next_state = RESET_EMPTY_PTR_STORAGE_S; 
            end
        end

      RESET_EMPTY_PTR_STORAGE_S:
        begin
          next_state = INIT_RAMS_S;
        end

      INIT_RAMS_S:
        begin
          if( data_table_init_done && head_table_init_done )
            next_state = DO_REPORT_S;
        end

      DO_REPORT_S:
        begin
          // waiting for report accepted
          if( result_valid_o && result_ready_i ) 
            next_state = IDLE_S;
        end

    endcase
  end

assign task_ready_o = ( state == IDLE_S );

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    task_locked <= '0;
  else
    if( task_ready_o && task_valid_i )
      task_locked <= task_i;

localparam CNT_W = ( BUCKET_WIDTH > A_WIDTH ) ? ( BUCKET_WIDTH ) : ( A_WIDTH ); 

logic [CNT_W-1:0] cnt_addr;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    cnt_addr <= '0;
  else
    if( state != INIT_RAMS_S )
      cnt_addr <= '0;
    else
      cnt_addr <= cnt_addr + 1'd1;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    head_table_init_done <= 1'b0;
  else
    if( state != INIT_RAMS_S )
     head_table_init_done <= 1'b0;
   else
     if( ( state == INIT_RAMS_S ) && ( head_table_if.wr_addr == '1 ) && head_table_if.wr_en )
       head_table_init_done <= 1'b1;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    data_table_init_done <= 1'b0;
  else
    if( state != INIT_RAMS_S )
      data_table_init_done <= 1'b0;
    else
      if( ( state == INIT_RAMS_S ) && ( data_table_if.wr_addr == '1 ) && data_table_if.wr_en )
        data_table_init_done <= 1'b1;

assign head_table_if.wr_addr         = cnt_addr[BUCKET_WIDTH-1:0];
assign head_table_if.wr_data_ptr     = '0; 
assign head_table_if.wr_data_ptr_val = 1'b0;
assign head_table_if.wr_en           = ( state == INIT_RAMS_S ) && ( head_table_init_done == 1'b0 ); 

assign data_table_if.wr_addr = cnt_addr[A_WIDTH-1:0]; 
assign data_table_if.wr_data = '0;
assign data_table_if.wr_en   = ( state == INIT_RAMS_S ) && ( data_table_init_done == 1'b0 );
// no read need here
assign data_table_if.rd_en     = 1'b0;
assign data_table_if.rd_addr   = 'x;

assign empty_ptr_storage_srst_o = ( state == RESET_EMPTY_PTR_STORAGE_S );
assign add_empty_ptr_o          = data_table_if.wr_addr;
assign add_empty_ptr_en_o       = data_table_if.wr_en;


always_comb
  begin
    result_o         = 'x;

    result_o.cmd     = task_locked.cmd;
    result_o.bucket  = 'x; // for OP_INIT bucket have no meaning

    result_o.rescode = INIT_SUCCESS; // always success init ^_^
  end

assign result_valid_o = ( state == DO_REPORT_S );

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

always_ff @( posedge clk_i )
  begin
    if( task_valid_i && task_ready_o )
      print_new_task( task_i );
    
    if( data_table_if.wr_en )
      print_ram_data( "WR", data_table_if.wr_addr, data_table_if.wr_data );

    if( result_valid_o && result_ready_i )
      print_result( "RES", result_o );

    print_state_transition( );
  end

// synthesis translate_on


endmodule
