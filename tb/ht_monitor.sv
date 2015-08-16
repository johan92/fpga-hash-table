`include "ht_dbg.vh"

class ht_monitor;
  
  mailbox #( ht_result_t ) mon2scb;

  virtual ht_res_if __if;

  function new( input mailbox #( ht_result_t ) _mon2scb, virtual ht_res_if _res_if );
    this.mon2scb = _mon2scb;
    this.__if    = _res_if;
  endfunction 
  
  task run( );
    fork
      receiver_thread( );    
    join
  endtask
  
  task receiver_thread( );
    ht_result_t r;

    forever
      begin
        receive_data( r );
        mon2scb.put( r );
      end
  endtask
  
  task receive_data( output ht_result_t r );
    r = '0;

    forever
      begin
        @( posedge __if.clk );
        if( __if.valid && __if.ready )
          begin
            r = __if.result;
            break;
          end
      end

    print_result( "IN_MONITOR", r );
  endtask

endclass
