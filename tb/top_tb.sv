import hash_table::*;

module top_tb;

localparam KEY_WIDTH        = 32;
localparam VALUE_WIDTH      = 16;
localparam BUCKET_WIDTH     = 8;
localparam HASH_TYPE        = "dummy";
localparam TABLE_ADDR_WIDTH = 10;

bit clk;
bit rst;
bit rst_done;

always #5ns clk = !clk;

ht_task_if #( 
  .KEY_WIDTH      ( KEY_WIDTH   ),
  .VALUE_WIDTH    ( VALUE_WIDTH )
) ht_task_in ( 
  .clk            ( clk         )
);

ht_res_if #( 
  .KEY_WIDTH      ( KEY_WIDTH   ),
  .VALUE_WIDTH    ( VALUE_WIDTH )
) ht_res_out ( 
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

    ht_task( 32'h01_00_00_00, 16'hAABB, SEARCH ); 
    
    ht_task( 32'h02_00_00_00, 16'hAABB, INSERT ); 

  end


hash_table_top #( 
  .KEY_WIDTH                              ( KEY_WIDTH        ), 
  .VALUE_WIDTH                            ( VALUE_WIDTH      ),
  .BUCKET_WIDTH                           ( BUCKET_WIDTH     ),
  .HASH_TYPE                              ( HASH_TYPE        ),
  .TABLE_ADDR_WIDTH                       ( TABLE_ADDR_WIDTH )
) dut (

  .clk_i                                  ( clk               ),
  .rst_i                                  ( rst               ),
    
  .ht_task_in                             ( ht_task_in        ),
  .ht_res_out                             ( ht_res_out        )

);

endmodule
