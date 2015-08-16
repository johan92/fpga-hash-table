class ht_driver;
  
  mailbox #( ht_command_t ) gen2drv;
  mailbox #( ht_command_t ) drv2scb;

  virtual ht_cmd_if __if;
  
  ht_command_t c;

  function new( input mailbox #( ht_command_t ) _drv2scb, virtual ht_cmd_if _cmd_if );
    this.gen2drv = new( );
    this.drv2scb = _drv2scb;
    this.__if    = _cmd_if;
    
    init_if( );
  endfunction
  
  function init_if( );
    this.__if.valid <= 1'b0;
    this.__if.cmd   <= '0;
  endfunction

  task run( );
    forever
      begin
        gen2drv.get( c );

        send_command( c );

        drv2scb.put( c );
      end
  endtask

  task send_command( input ht_command_t cmd );
    __if.cmd    <= cmd;
    __if.valid  <= 1'b1;

    @( posedge __if.clk );

    forever
      begin
        if( __if.ready )
          break;
        else
          @( posedge __if.clk );
      end
     __if.valid <= 1'b0;
  endtask

endclass
