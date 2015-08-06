import hash_table::*;

module top_tb;

bit clk;
bit rst;
bit rst_done;

always #5ns clk = !clk;

ht_task_if ht_task_in ( 
  .clk            ( clk         )
);

ht_res_if ht_res_out ( 
  .clk            ( clk         )
);

// now is always ready
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

// FIXME - now we don't care about ready  
task ht_task( input bit [KEY_WIDTH-1:0] _key, bit [VALUE_WIDTH-1:0] _value, ht_cmd_t _cmd );
  repeat( 20 ) @( posedge clk );
  @( posedge clk );
  ht_task_in.key   <= _key;
  ht_task_in.value <= _value;
  ht_task_in.cmd   <= _cmd;
  ht_task_in.valid <= 1'b0;
  
  @( posedge clk );
  ht_task_in.valid <= 1'b1;
  
  @( posedge clk );
  ht_task_in.valid <= 1'b0;
endtask

initial
  begin
    wait( rst_done )
    dut.head_ptr_table.write_to_head_ptr_ram( 1, 1, 1'b1 );
    dut.head_ptr_table.write_to_head_ptr_ram( 2, 7, 1'b1 );

    dut.data_table.write_to_data_ram( 1, 32'h01_00_00_00, 16'h1234, 2, 1'b1 );
    dut.data_table.write_to_data_ram( 2, 32'h01_00_00_01, 16'h5678, 0, 1'b0 );
    
    dut.data_table.write_to_data_ram( 7, 32'h02_00_00_00, 16'hABCD, 0, 1'b0 );

    ht_task( 32'h01_00_00_00, 16'hAABB, SEARCH ); 
    
    ht_task( 32'h02_00_00_00, 16'hAABB, INSERT ); 

  end


hash_table_top dut(

  .clk_i                                  ( clk               ),
  .rst_i                                  ( rst               ),
    
  .ht_task_in                             ( ht_task_in        ),
  .ht_res_out                             ( ht_res_out        )

);

endmodule
