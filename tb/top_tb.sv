import hash_table::*;
import ht_tb::*;

module top_tb;

bit clk;
bit rst;
bit rst_done;

ht_environment env;

always #5ns clk = !clk;

ht_cmd_if ht_cmd_in ( 
  .clk            ( clk         )
);

ht_res_if ht_res_out ( 
  .clk            ( clk         )
);

// now it's always ready
assign ht_res_out.ready = 1'b1;

initial
  begin
    rst <= 1'b1;

    @( posedge clk );
    @( posedge clk );
    @( negedge clk );
    rst <= 1'b0;
    rst_done <= 1'b1;
  end

task send_to_dut( input bit [KEY_WIDTH-1:0] _key, bit [VALUE_WIDTH-1:0] _value, ht_opcode_t _opcode );
  ht_command_t cmd;
  cmd.key    = _key;
  cmd.value  = _value;
  cmd.opcode = _opcode;
  
  // using hierarchial access to put command in mailbox
  env.drv.gen2drv.put( cmd );
endtask 

initial
  begin
    wait( rst_done )
    @( posedge clk );
    send_to_dut( 32'h01_00_00_00, 16'h1234, OP_INSERT ); 
    send_to_dut( 32'h01_00_00_01, 16'h1235, OP_INSERT ); 
    send_to_dut( 32'h01_00_00_01, 16'h1235, OP_DELETE ); 
    send_to_dut( 32'h01_00_00_00, 16'h0000, OP_SEARCH ); 
    send_to_dut( 32'h02_00_00_00, 16'h0000, OP_SEARCH ); 
    send_to_dut( 32'h01_00_00_00, 16'h0000, OP_SEARCH ); 
    send_to_dut( 32'h02_00_00_00, 16'h0000, OP_SEARCH ); 
    ////ht_task( 32'h01_00_00_01, 16'h0000, SEARCH ); 
    //ht_task( 32'h01_00_00_00, 16'h0000, SEARCH ); 
    //ht_task( 32'h01_00_00_00, 16'h0000, SEARCH ); 
    //ht_task( 32'h01_00_00_00, 16'h0000, SEARCH ); 
    //ht_task( 32'h01_00_00_00, 16'h0000, SEARCH ); 
    //ht_task( 32'h01_00_00_00, 16'h0000, SEARCH ); 
    //ht_task( 32'h02_00_00_00, 16'h0000, SEARCH ); 
    //ht_task( 32'h01_00_00_00, 16'h0000, SEARCH ); 
    //ht_task( 32'h02_00_00_00, 16'h0000, SEARCH ); 
    //ht_task( 32'h01_00_00_00, 16'h0000, SEARCH ); 
    //ht_task( 32'h02_00_00_00, 16'h0000, SEARCH ); 
    //ht_task( 32'h01_00_00_00, 16'h0000, SEARCH ); 
    //ht_task( 32'h02_00_00_00, 16'h0000, SEARCH ); 
    //ht_task( 32'h01_00_00_00, 16'h0000, SEARCH ); 
    //ht_task( 32'h02_00_00_00, 16'h0000, SEARCH ); 
    //ht_task( 32'h01_00_00_00, 16'h0000, SEARCH ); 
    //ht_task( 32'h02_00_00_00, 16'h0000, SEARCH ); 

    //
    //ht_task( 32'h02_00_00_00, 16'hAABB, SEARCH ); 

    //ht_task( 32'h11_22_33_44, 16'h0000, SEARCH ); 

  end


initial
  begin
    env = new( );
    env.build( ht_cmd_in, ht_res_out );

    wait( rst_done );
    @( posedge clk );
    @( posedge clk );
    @( posedge clk );

    env.run( );
  end

hash_table_top dut(

  .clk_i                                  ( clk               ),
  .rst_i                                  ( rst               ),
    
  .ht_cmd_in                              ( ht_cmd_in         ),
  .ht_res_out                             ( ht_res_out        )

);

endmodule
