//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

`include "ht_dbg.vh"

class ht_monitor;
  
  mailbox #( ht_result_t ) mon2scb;

  virtual ht_res_if __if;
  
  ht_result_t r;
  
  // ******* Coverage Stuff *******
  localparam HISTORY_DELAY = 2;
  localparam BUCKET_CNT    = 2**hash_table::BUCKET_WIDTH;

  int                            bucket_occup     [BUCKET_CNT-1  : 0]; 
  ht_result_t                    r_history        [HISTORY_DELAY : 1];
  logic        [HISTORY_DELAY:1] bucket_hist_mask;

  covergroup cg( );
    option.per_instance = 1;

    CMDOP:      coverpoint r.cmd.opcode;
    CMDRES:     coverpoint r.rescode;

    CMDOP_D1:   coverpoint r_history[1].cmd.opcode;
    CMDOP_D2:   coverpoint r_history[2].cmd.opcode;

    CMDRES_D1:  coverpoint r_history[1].rescode;
    CMDRES_D2:  coverpoint r_history[2].rescode;
    
    CHAIN:      coverpoint r.chain_state;

    BUCK_HIST_MASK: coverpoint bucket_hist_mask;

    BUCKOCUP: coverpoint bucket_occup[ r.bucket ] {
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
  
  // ******* *******
  
  function new( input mailbox #( ht_result_t ) _mon2scb, virtual ht_res_if _res_if );
    this.mon2scb = _mon2scb;
    this.__if    = _res_if;
    this.cg      = new( );
  endfunction 
  
  task run( );
    fork
      receiver_thread( );    
    join
  endtask
  
  task receiver_thread( );

    forever
      begin
        receive_data(  );
        mon2scb.put( r );
        

        cg_pre_sample( );

        this.cg.sample( );

        cg_post_sample( );
      end
  endtask
  
  task receive_data( );
    r = '0;

    forever
      begin
        @( __if.cb );
        if( __if.cb.accepted )
          begin
            r = __if.cb.result;
            break;
          end
      end

    print_result( "IN_MONITOR", r );
  endtask

  task cg_pre_sample( );
    for( int i = 1; i <= HISTORY_DELAY; i++ )
      bucket_hist_mask[i] = ( r_history[i].bucket == r.bucket );
  endtask 

  task cg_post_sample( );
    
    // recalc bucket occup
    case( r.rescode )

      INIT_SUCCESS:
        begin
          for( int i = 0; i < BUCKET_CNT; i++ )
            begin
              bucket_occup[i] = 0;
            end
        end

      INSERT_SUCCESS: bucket_occup[ r.bucket ] += 1;
      DELETE_SUCCESS: bucket_occup[ r.bucket ] -= 1;

      default:
        begin
          // do nothing
        end
      
    endcase
    
    // make history =)
    r_history[1] = r;

    for( int i = 2; i <= HISTORY_DELAY; i++ )
      begin
        r_history[i] = r_history[ i - 1 ];
      end
  endtask
  
endclass
