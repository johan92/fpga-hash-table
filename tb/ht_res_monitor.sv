import hash_table::*;

interface ht_res_monitor(

  input             clk_i,

  input ht_result_t result_i,
  input             result_valid_i,
  input             result_ready_i

);

localparam BUCKET_CNT = 2**BUCKET_WIDTH;

ht_result_t result_locked;
logic       result_locked_val = 1'b0;

int bucket_occup[BUCKET_CNT-1:0]; 

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
 
covergroup cg();

  option.per_instance = 1;

  CMDOP:    coverpoint result_locked.cmd.opcode;
  CMDRES:   coverpoint result_locked.rescode;

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
