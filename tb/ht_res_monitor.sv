//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

import hash_table::*;

interface ht_res_monitor(

  input             clk_i,

  input ht_result_t result_i,
  input             result_valid_i,
  input             result_ready_i

);

localparam BUCKET_CNT    = 2**BUCKET_WIDTH;
localparam HISTORY_DELAY = 2;

ht_result_t result_locked;
logic       result_locked_val = 1'b0;

int         bucket_occup   [BUCKET_CNT-1:0]; 
ht_result_t result_history [HISTORY_DELAY:1];

sequence ABC;
  @( posedge clk_i )
  //$rose( result_valid_i && result_ready_i );
  ( result_valid_i && result_ready_i );
endsequence 


always_ff @( negedge clk_i )
  if( result_valid_i && result_ready_i )
    result_locked <= result_i;

always_ff @( negedge clk_i )
  result_locked_val <= result_valid_i && result_ready_i;

always_ff @( negedge clk_i )
  begin
    if( result_locked_val )
      begin
        if     ( result_locked.rescode == INSERT_SUCCESS ) bucket_occup[ result_locked.bucket ] += 1;
        else if( result_locked.rescode == DELETE_SUCCESS ) bucket_occup[ result_locked.bucket ] -= 1;
      end
  end

always_ff @( negedge clk_i )
  begin
    if( result_locked_val )
      begin
        result_history[1] <= result_locked;

        for( int i = 2; i <= HISTORY_DELAY; i++ )
          begin
            result_history[i] <= result_history[i-1];
          end
      end
  end

logic [HISTORY_DELAY:1] bucket_hist_mask;

always_comb
  begin
    for( int i = 1; i <= HISTORY_DELAY; i++ )
      bucket_hist_mask[i] = ( result_history[i].bucket == result_locked.bucket );
  end


covergroup cg();

  option.per_instance = 1;

  CMDOP:      coverpoint result_locked.cmd.opcode;
  CMDRES:     coverpoint result_locked.rescode;

  CMDOP_D1:   coverpoint result_history[1].cmd.opcode;
  CMDOP_D2:   coverpoint result_history[2].cmd.opcode;

  CMDRES_D1:  coverpoint result_history[1].rescode;
  CMDRES_D2:  coverpoint result_history[2].rescode;
  
  CHAIN:      coverpoint result_locked.chain_state;

  BUCK_HIST_MASK: coverpoint bucket_hist_mask;

  BUCKOCUP: coverpoint bucket_occup[ result_locked.bucket ] {
    bins zero   = { 0 };
    bins one    = { 1 };
    bins two    = { 2 };
    bins three  = { 3 };
    bins four   = { 4 };
    bins other  = { [5:$] };
  }
  
  CMDOP_BUCKOCUP: cross CMDOP, BUCKOCUP; 

  CMDRES_BUCKOCUP: cross CMDRES, BUCKOCUP {
    // we should ignore SEARCH_FOUND, INSERT_SUCCESS_SAME_KEY, DELETE_SUCCESS 
    // when in bucket was zero elements, because it's not real situation
    ignore_bins not_real = binsof( CMDRES   ) intersect{ SEARCH_FOUND, INSERT_SUCCESS_SAME_KEY, DELETE_SUCCESS  } && 
                           binsof( BUCKOCUP ) intersect{ 0 };
  }
  
  CMDOP_HISTORY_D2: cross CMDOP_D2, CMDOP_D1, CMDOP, BUCK_HIST_MASK;
  
  CMDRES_HISTORY_D2: cross CMDRES_D2, CMDRES_D1, CMDRES, BUCK_HIST_MASK {
    ignore_bins not_check_now = binsof( CMDRES    ) intersect{ INSERT_NOT_SUCCESS_TABLE_IS_FULL } || 
                                binsof( CMDRES_D1 ) intersect{ INSERT_NOT_SUCCESS_TABLE_IS_FULL } ||
                                binsof( CMDRES_D2 ) intersect{ INSERT_NOT_SUCCESS_TABLE_IS_FULL };
  }
  
  CMDOP_CHAIN: cross CMDOP, CHAIN {
    ignore_bins insert_in_middle        = binsof( CMDOP ) intersect { OP_INSERT        } && 
                                          binsof( CHAIN ) intersect { IN_MIDDLE        };

    ignore_bins insert_in_tail_no_match = binsof( CMDOP ) intersect { OP_INSERT        } && 
                                          binsof( CHAIN ) intersect { IN_TAIL_NO_MATCH };

  }
endgroup

cg cg1;

initial
  begin
    cg1 = new();
  end

cover property( ABC )
  begin
    cg1.sample();
  end

endinterface
