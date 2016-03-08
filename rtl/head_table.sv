//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

import hash_table::*;

module head_table (

  input                        clk_i,
  input                        rst_i,
  
  input        ht_pdata_t      pdata_in_i,
  input                        pdata_in_valid_i,
  output logic                 pdata_in_ready_o,

  output       ht_pdata_t      pdata_out_o,
  output                       pdata_out_valid_o,
  input                        pdata_out_ready_i,
  
  head_table_if.slave          head_table_if

);

localparam D_WIDTH = $bits( head_ram_data_t );
localparam A_WIDTH = BUCKET_WIDTH;

logic [A_WIDTH-1:0]    wr_addr;
logic [A_WIDTH-1:0]    rd_addr;
logic                  rd_en;

head_ram_data_t        wr_data;
head_ram_data_t        rd_data;
logic                  wr_en;

ht_pdata_t             prev_pdata;
logic                  prev_pdata_en;

// bp - backpressure
logic                  bp_pdata_in_valid;
logic                  bp_pdata_in_ready;

logic                  need_backpressure;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    prev_pdata <= '0;
  else
    if( pdata_in_valid_i && pdata_in_ready_o )
      prev_pdata <= pdata_in_i;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    prev_pdata_en <= 1'b0;
  else
    if( pdata_in_valid_i && pdata_in_ready_o )
      prev_pdata_en <= 1'b1;
    else
      prev_pdata_en <= 1'b0;

// FIXME: prev_pdata.cmd.opcode == OP_INIT is wrong here,
//        need backpreasure in another place
assign need_backpressure = ( prev_pdata.cmd.opcode == OP_INIT ) ||
                           (
                             ( prev_pdata.bucket == pdata_in_i.bucket ) &&
                             ( 
                               ( prev_pdata.cmd.opcode == OP_INSERT ) ||
                               ( prev_pdata.cmd.opcode == OP_DELETE )
                             ) 
                           );
always_comb
  begin
    bp_pdata_in_valid = pdata_in_valid_i;
    pdata_in_ready_o  = bp_pdata_in_ready;

    if( need_backpressure )
      begin
        if( prev_pdata_en )
          begin
            bp_pdata_in_valid = 1'b0;
            pdata_in_ready_o  = 1'b0; 
          end
        else
          begin
            // waiting for input ready 
            bp_pdata_in_valid &= pdata_out_ready_i; 
            pdata_in_ready_o  &= pdata_out_ready_i;
          end
      end
  end

assign rd_addr = pdata_in_i.bucket;
assign rd_en   = bp_pdata_in_valid && pdata_in_ready_o;

true_dual_port_ram_single_clock #( 
  .DATA_WIDTH                             ( D_WIDTH           ), 
  .ADDR_WIDTH                             ( A_WIDTH           ), 
  .REGISTER_OUT                           ( 0                 )
) head_ram (
  .clk                                    ( clk_i             ),

  .addr_a                                 ( rd_addr           ),
  .data_a                                 ( {D_WIDTH{1'b0}}   ),
  .re_a                                   ( rd_en             ), 
  .we_a                                   ( 1'b0              ),
  .q_a                                    ( rd_data           ),

  .addr_b                                 ( wr_addr           ),
  .data_b                                 ( wr_data           ),
  .we_b                                   ( wr_en             ),
  .re_b                                   ( 1'b0              ),
  .q_b                                    (                   )
);

// using last data like cache 
logic [A_WIDTH-1:0] last_wr_addr; 
head_ram_data_t     last_wr_data; 

always_ff @( posedge clk_i )
  if( wr_en )
    begin
      last_wr_addr <= wr_addr;
      last_wr_data <= wr_data;
    end

assign wr_addr          = head_table_if.wr_addr;
assign wr_data          = head_table_if.wr_data;
assign wr_en            = head_table_if.wr_en; 

ht_pdata_t pdata_in_d1;
logic      pdata_in_d1_valid;
logic      pdata_in_d1_ready;

ht_delay #(
  .D_WIDTH                                ( $bits( pdata_in_d1 ) ),
  .DELAY                                  ( 1                    ),
  .PIPELINE_READY                         ( 0                    )
) ht_d1 (
  .clk_i                                  ( clk_i                ),
  .rst_i                                  ( rst_i                ),

  .data_in_i                              ( pdata_in_i           ),
  .data_in_valid_i                        ( bp_pdata_in_valid    ),
  .data_in_ready_o                        ( bp_pdata_in_ready    ),

  .data_out_o                             ( pdata_in_d1          ),
  .data_out_valid_o                       ( pdata_in_d1_valid    ),
  .data_out_ready_i                       ( pdata_in_d1_ready    )

);

always_comb
  begin
    pdata_out_o              = pdata_in_d1;
    
    // this is one more workaround for backpressuring 
    if( last_wr_addr == pdata_in_d1.bucket )
      begin
        pdata_out_o.head_ptr     = last_wr_data.ptr; 
        pdata_out_o.head_ptr_val = last_wr_data.ptr_val;
      end
    else
      begin
        pdata_out_o.head_ptr     = rd_data.ptr; 
        pdata_out_o.head_ptr_val = rd_data.ptr_val;
      end
  end

assign pdata_out_valid_o = pdata_in_d1_valid;
assign pdata_in_d1_ready = pdata_out_ready_i;


// synthesis translate_off
`include "../tb/ht_dbg.vh"

function void print_wr_head_table( );
  string msg;
  $sformat( msg, "addr = 0x%x wr_data.ptr = 0x%x wr_data.ptr_val = 0x%x", wr_addr, wr_data.ptr, wr_data.ptr_val );
  print( msg );
endfunction

always_ff @( posedge clk_i )
  begin
    if( wr_en )
      print_wr_head_table( );
  end

// synthesis translate_on

endmodule
