/*
  Environment that just creates driver, monitor and scoreboard,
  and connect all stuff :) 

*/

`ifndef _HT_ENVIRONMENT_
`define _HT_ENVIRONMENT_

class ht_environment;
  
  ht_driver     drv;
  ht_monitor    mon;
  ht_scoreboard scb;
  
  mailbox #( ht_command_t ) drv2scb; 
  mailbox #( ht_result_t  ) mon2scb; 

  function void build( input virtual ht_cmd_if _cmd_if, virtual ht_res_if _res_if );
    drv2scb = new( );
    mon2scb = new( );

    drv = new( drv2scb,         _cmd_if );
    mon = new( mon2scb,         _res_if );
    scb = new( drv2scb, mon2scb         );
  endfunction 
  
  task run( );
    fork
      drv.run( );
      mon.run( );
      scb.run( );
    join
  endtask

endclass

`endif
