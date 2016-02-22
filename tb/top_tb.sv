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

task send_to_dut_c( input ht_command_t c );
  // using hierarchial access to put command in mailbox
  env.drv.gen2drv.put( c );
endtask

function bit [KEY_WIDTH-1:0] gen_rand_key( int max_bucket_num = ( 2**BUCKET_WIDTH - 1 ), 
                                           int max_key_value  = ( 2**( KEY_WIDTH - BUCKET_WIDTH ) - 1 ) );
  bit [BUCKET_WIDTH-1:0] bucket_num;
  bit [KEY_WIDTH-1:0]    gen_key;

  if( hash_table::HASH_TYPE != "dummy" )
    begin
      $display("%m: hash_type = %s not supported here!", hash_table::HASH_TYPE );
      $fatal();
    end

  bucket_num = $urandom_range( max_bucket_num , 0 );
  gen_key    = $urandom_range( max_key_value, 0 );
  
  // replace high bits by bucket_num (is needs in dummy hash)
  gen_key[ KEY_WIDTH - 1 : KEY_WIDTH - BUCKET_WIDTH ] = bucket_num;
  
  return gen_key;
endfunction

`define CMD( _OP, _KEY, _VALUE ) cmds.push_back( '{ opcode : _OP, key : _KEY, value : _VALUE } ); 

`define CMD_SEARCH( _KEY )         `CMD( OP_SEARCH, _KEY, 0 )

`define CMD_INSERT( _KEY, _VALUE ) `CMD( OP_INSERT, _KEY, _VALUE )

`define CMD_INSERT_RAND( _KEY )    `CMD_INSERT( _KEY, $urandom() )

`define CMD_DELETE( _KEY )         `CMD( OP_DELETE, _KEY, 0 )

task test_01( );
  ht_command_t cmds[$];
  $display("%m:");
  
  `CMD_INSERT( 32'h01_00_00_00, 16'h1234 )
  `CMD_INSERT( 32'h01_00_10_00, 16'h1235 )

  `CMD_INSERT_RAND( 32'h01_00_00_00 )
  `CMD_INSERT_RAND( 32'h01_00_00_01 )
  `CMD_DELETE     ( 32'h01_00_00_00 )
  `CMD_INSERT_RAND( 32'h01_00_00_02 )

  `CMD_SEARCH( 32'h01_00_00_00 )
  `CMD_SEARCH( 32'h01_00_00_01 )
  `CMD_SEARCH( 32'h01_00_00_01 )
  `CMD_SEARCH( 32'h01_00_00_03 )
  

  foreach( cmds[i] )
    begin
      send_to_dut_c( cmds[i] );
    end
endtask

task test_02( );
  ht_command_t cmds[$];
  
  $display("%m:");
  
  `CMD_INSERT_RAND( 32'h00_00_00_00 )
  `CMD_INSERT_RAND( 32'h01_00_00_00 )
  `CMD_INSERT_RAND( 32'h02_00_00_00 )
  `CMD_INSERT_RAND( 32'h03_00_00_00 )

  `CMD_SEARCH( 32'h03_00_00_00 )
  `CMD_SEARCH( 32'h02_00_00_00 )
  `CMD_SEARCH( 32'h01_00_00_00 )
  `CMD_SEARCH( 32'h00_00_00_00 )
  
  `CMD_DELETE( 32'h00_00_00_00 )
  `CMD_DELETE( 32'h01_00_00_00 )
  `CMD_DELETE( 32'h02_00_00_00 )
  `CMD_DELETE( 32'h03_00_00_00 )

  foreach( cmds[i] )
    begin
      send_to_dut_c( cmds[i] );
    end
endtask

task test_03( );
  ht_command_t cmds[$];
  
  $display("%m:");
  
  `CMD_SEARCH      ( 32'h04_00_00_00 )
  `CMD_DELETE      ( 32'h04_11_11_11 )

  `CMD_INSERT_RAND ( 32'h04_00_00_00 )
  `CMD_SEARCH      ( 32'h04_10_00_00 )
  `CMD_SEARCH      ( 32'h04_00_00_00 )
  `CMD_DELETE      ( 32'h04_10_00_00 )
  
  `CMD_INSERT_RAND ( 32'h04_00_00_01 )
  `CMD_SEARCH      ( 32'h04_10_00_01 )
  `CMD_SEARCH      ( 32'h04_00_00_01 )
  `CMD_DELETE      ( 32'h04_10_00_01 )
  
  `CMD_INSERT_RAND ( 32'h04_00_00_02 )
  `CMD_SEARCH      ( 32'h04_10_00_02 )
  `CMD_SEARCH      ( 32'h04_00_00_02 )
  `CMD_DELETE      ( 32'h04_10_00_02 )
  
  `CMD_INSERT_RAND ( 32'h04_00_00_03 )
  `CMD_SEARCH      ( 32'h04_10_00_03 )
  `CMD_SEARCH      ( 32'h04_00_00_03 )
  `CMD_DELETE      ( 32'h04_10_00_03 )
  
  `CMD_INSERT_RAND ( 32'h04_00_00_04 )
  `CMD_SEARCH      ( 32'h04_10_00_04 )
  `CMD_SEARCH      ( 32'h04_00_00_04 )
  `CMD_DELETE      ( 32'h04_10_00_04 )
  
  `CMD_INSERT_RAND ( 32'h04_00_00_05 )
  `CMD_SEARCH      ( 32'h04_10_00_05 )
  `CMD_SEARCH      ( 32'h04_00_00_05 )
  `CMD_DELETE      ( 32'h04_10_00_05 )
  
  `CMD_INSERT_RAND ( 32'h04_00_00_00 )
  `CMD_DELETE      ( 32'h04_00_00_00 )
  
  `CMD_INSERT_RAND ( 32'h04_00_00_01 )
  `CMD_DELETE      ( 32'h04_00_00_01 )
  
  `CMD_INSERT_RAND ( 32'h04_00_00_02 )
  `CMD_DELETE      ( 32'h04_00_00_02 )
  
  `CMD_INSERT_RAND ( 32'h04_00_00_03 )
  `CMD_DELETE      ( 32'h04_00_00_03 )
  
  `CMD_INSERT_RAND ( 32'h04_00_00_04 )
  `CMD_DELETE      ( 32'h04_00_00_04 )
  
  `CMD_INSERT_RAND ( 32'h04_00_00_05 )
  `CMD_DELETE      ( 32'h04_00_00_05 )

  foreach( cmds[i] )
    begin
      send_to_dut_c( cmds[i] );
    end

endtask

task test_04( );
  ht_command_t cmds[$];
  
  $display("%m:");

  `CMD_INSERT_RAND( 32'h05_00_00_00 )
  `CMD_INSERT_RAND( 32'h05_00_00_01 )
  
  `CMD_DELETE     ( 32'h05_00_00_01 )
  
  `CMD_INSERT_RAND( 32'h05_00_00_02 )
  `CMD_INSERT_RAND( 32'h05_00_00_03 )
  
  foreach( cmds[i] )
    begin
      send_to_dut_c( cmds[i] );
    end
endtask 

task test_05( );
  ht_command_t cmds[$];
  
  $display("%m:");
  
  for( int c = 0; c < 5000; c++ )
    begin
      `CMD_SEARCH      ( gen_rand_key( 15, 7 ) )
      `CMD_INSERT_RAND ( gen_rand_key( 15, 7 ) )
      `CMD_DELETE      ( gen_rand_key( 15, 7 ) )
    end
  
  cmds.shuffle( );

  foreach( cmds[i] )
    begin
      send_to_dut_c( cmds[i] );
    end

endtask

task test_06( );
  ht_command_t cmds[$];
  
  $display("%m:");

  for( int c = 0; c < 1000; c++ )
    begin
      `CMD_SEARCH     ( gen_rand_key( 0, 7 ) )
      `CMD_INSERT_RAND( gen_rand_key( 0, 7 ) )
      `CMD_DELETE     ( gen_rand_key( 0, 7 ) )
    end
  
  cmds.shuffle( );

  foreach( cmds[i] )
    begin
      send_to_dut_c( cmds[i] );
    end

endtask

initial
  begin
    wait( rst_done )
    @( posedge clk );
    test_01( );
    test_02( );
    test_03( );
    test_04( );
    //test_05( );
    //test_06( );
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
