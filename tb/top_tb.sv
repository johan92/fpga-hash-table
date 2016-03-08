//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

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

function bit [KEY_WIDTH-1:0] gen_rand_key( int min_bucket_num  = 0,
                                           int max_bucket_num = ( 2**BUCKET_WIDTH - 1 ), 
                                           int max_key_value  = ( 2**( KEY_WIDTH - BUCKET_WIDTH ) - 1 ) );
  bit [BUCKET_WIDTH-1:0] bucket_num;
  bit [KEY_WIDTH-1:0]    gen_key;

  if( hash_table::HASH_TYPE != "dummy" )
    begin
      $display("%m: hash_type = %s not supported here!", hash_table::HASH_TYPE );
      $fatal();
    end

  bucket_num = $urandom_range( max_bucket_num, min_bucket_num );
  gen_key    = $urandom_range( max_key_value,  0              );
  
  // replace high bits by bucket_num (is needs in dummy hash)
  gen_key[ KEY_WIDTH - 1 : KEY_WIDTH - BUCKET_WIDTH ] = bucket_num;
  
  return gen_key;
endfunction

`define CMD( _OP, _KEY, _VALUE ) cmds.push_back( '{ opcode : _OP, key : _KEY, value : _VALUE } ); 

`define CMD_INIT( x )              `CMD( OP_INIT, 0, 0 )

`define CMD_SEARCH( _KEY )         `CMD( OP_SEARCH, _KEY, 0 )

`define CMD_INSERT( _KEY, _VALUE ) `CMD( OP_INSERT, _KEY, _VALUE )

`define CMD_INSERT_RAND( _KEY )    `CMD_INSERT( _KEY, $urandom() )

`define CMD_DELETE( _KEY )         `CMD( OP_DELETE, _KEY, 0 )

task init_hash_table( );
  ht_command_t cmds[$];
  $display("%m:");

  `CMD_INIT( );

  foreach( cmds[i] )
    begin
      send_to_dut_c( cmds[i] );
    end
endtask

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

// testing small amount of buckets with random commands
task test_05( );
  ht_command_t cmds[$];
  
  $display("%m:");
  
  for( int c = 0; c < 5000; c++ )
    begin
      `CMD_SEARCH      ( gen_rand_key( 0, 15, 7 ) )
      `CMD_INSERT_RAND ( gen_rand_key( 0, 15, 7 ) )
      `CMD_DELETE      ( gen_rand_key( 0, 15, 7 ) )
    end
  
  cmds.shuffle( );

  foreach( cmds[i] )
    begin
      send_to_dut_c( cmds[i] );
    end

endtask

// testing only one bucket with random commands
task test_06( );
  ht_command_t cmds[$];
  
  $display("%m:");

  for( int c = 0; c < 1000; c++ )
    begin
      `CMD_SEARCH     ( gen_rand_key( 0, 0, 7 ) )
      `CMD_INSERT_RAND( gen_rand_key( 0, 0, 7 ) )
      `CMD_DELETE     ( gen_rand_key( 0, 0, 7 ) )
    end
  
  cmds.shuffle( );

  foreach( cmds[i] )
    begin
      send_to_dut_c( cmds[i] );
    end

endtask

// just inserting a lot data 
task test_07( input int insert_cmd_cnt );
  ht_command_t cmds[$];
  
  $display("%m:");

  for( int c = 0; c < insert_cmd_cnt; c++ )
    begin
      `CMD_INSERT_RAND( gen_rand_key( ) );
    end
  
  foreach( cmds[i] )
    begin
      send_to_dut_c( cmds[i] );
    end
endtask

task test_08( input int search_cmd_cnt, 
              input int delete_cmd_cnt );

  ht_command_t cmds[$];
  bit [KEY_WIDTH-1:0] existing_key;

  for( int c = 0; c < search_cmd_cnt; c++ )
    begin
      if( env.scb.ref_ht.get_key_that_exists( existing_key ) == 0 )
        begin
          `CMD_SEARCH( existing_key );
        end
    end

  for( int c = 0; c < delete_cmd_cnt; c++ )
    begin
      if( env.scb.ref_ht.get_key_that_exists( existing_key ) == 0 )
        begin
          `CMD_DELETE( existing_key );
        end
    end

  cmds.shuffle( );

  foreach( cmds[i] )
    begin
      send_to_dut_c( cmds[i] );
    end

endtask

task wait_end_of_tests( );
  
  forever
    begin
      @( posedge clk );
      if( env.mailboxs_is_empty() )
        begin
          break;
        end
    end

  // few more ticks 
  repeat( 5 ) @( posedge clk );

  $info("Tests ended!");
endtask

initial
  begin
    wait( rst_done )
    @( posedge clk );

    init_hash_table( );
    
    test_01( );
    test_02( );
    test_03( );
    test_04( );
    
    init_hash_table( );

    test_05( );
    
    init_hash_table( );
    
    test_06( );
    
    init_hash_table( );
    
    test_07( 2**TABLE_ADDR_WIDTH + 10 );
    test_08( 100, 200 );

    wait_end_of_tests( );

    $stop();
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

ht_res_monitor resm(
  .clk_i                                  ( clk                ),

  .result_i                               ( ht_res_out.result  ),
  .result_valid_i                         ( ht_res_out.valid   ),
  .result_ready_i                         ( ht_res_out.ready   )

);

head_ram_data_t                        tm_head_table_wr_data;
logic           [BUCKET_WIDTH-1:0]     tm_head_table_wr_addr;
logic                                  tm_head_table_wr_en;

  // data table
ram_data_t                             tm_data_table_wr_data;
logic           [TABLE_ADDR_WIDTH-1:0] tm_data_table_wr_addr;
logic                                  tm_data_table_wr_en;
logic           [TABLE_ADDR_WIDTH-1:0] tm_data_table_rd_addr;
logic                                  tm_data_table_rd_en;

logic                                  empty_ptr_srst;

logic           [TABLE_ADDR_WIDTH-1:0] empty_ptr_add_addr;
logic                                  empty_ptr_add_addr_en;

logic           [TABLE_ADDR_WIDTH-1:0] empty_ptr_del_addr;
logic                                  empty_ptr_del_addr_en;

// via hierarical access getting wires
assign tm_head_table_wr_data         = dut.head_table_if.wr_data;
assign tm_head_table_wr_addr         = dut.head_table_if.wr_addr;
assign tm_head_table_wr_en           = dut.head_table_if.wr_en;

assign tm_data_table_wr_data         = dut.d_tbl.data_table_ram_if.wr_data; 
assign tm_data_table_wr_addr         = dut.d_tbl.data_table_ram_if.wr_addr;
assign tm_data_table_wr_en           = dut.d_tbl.data_table_ram_if.wr_en;
assign tm_data_table_rd_addr         = dut.d_tbl.data_table_ram_if.rd_addr;
assign tm_data_table_rd_en           = dut.d_tbl.data_table_ram_if.rd_en;

assign empty_ptr_srst                = dut.d_tbl.empty_ptr_storage_srst_w;
assign empty_ptr_add_addr            = dut.d_tbl.add_empty_ptr; 
assign empty_ptr_add_addr_en         = dut.d_tbl.add_empty_ptr_en;
assign empty_ptr_del_addr            = dut.d_tbl.empty_addr;
assign empty_ptr_del_addr_en         = dut.d_tbl.empty_addr_rd_ack && 
                                       dut.d_tbl.empty_addr_val;
tables_monitor tm(

  .clk_i                                  ( clk                    ),
  .rst_i                                  ( rst                    ),

  // head_ptr table
  .head_table_wr_data_i                   ( tm_head_table_wr_data  ),
  .head_table_wr_addr_i                   ( tm_head_table_wr_addr  ),
  .head_table_wr_en_i                     ( tm_head_table_wr_en    ),

  // data table
  .data_table_wr_data_i                   ( tm_data_table_wr_data  ),
  .data_table_wr_addr_i                   ( tm_data_table_wr_addr  ),
  .data_table_wr_en_i                     ( tm_data_table_wr_en    ),

  .data_table_rd_addr_i                   ( tm_data_table_rd_addr  ),
  .data_table_rd_en_i                     ( tm_data_table_rd_en    ),

  .empty_ptr_srst_i                       ( empty_ptr_srst         ),
  .empty_ptr_add_addr_i                   ( empty_ptr_add_addr     ),
  .empty_ptr_add_addr_en_i                ( empty_ptr_add_addr_en  ),

  .empty_ptr_del_addr_i                   ( empty_ptr_del_addr     ),
  .empty_ptr_del_addr_en_i                ( empty_ptr_del_addr_en  )
);

endmodule
