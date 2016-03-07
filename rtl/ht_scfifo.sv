//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

module ht_scfifo #(
  parameter DATA_W = 10,
  parameter ADDR_W = 8
) (
  input               clk_i,
  input               rst_i,

  input               srst_i,

  input [DATA_W-1:0]  wr_data_i,
  input               wr_req_i,
 
  input               rd_req_i,
  output [DATA_W-1:0] rd_data_o,

  output              empty_o,
  output              full_o
  
);
localparam MAX_WORDS_CNT = 2**ADDR_W;

logic [ADDR_W-1:0] rd_ptr;
logic [ADDR_W-1:0] wr_ptr;
logic [ADDR_W:0]   words_cnt;

logic              valid_rd_req;
logic              valid_wr_req;

// FIXME: maybe we need to use next_rd_ptr here to implement true showahead fifo

assign valid_rd_req = ( empty_o == 1'b0 ) && rd_req_i;
assign valid_wr_req = ( full_o  == 1'b0 ) && wr_req_i;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    rd_ptr <= '0;
  else
    if( srst_i )
      rd_ptr <= 1'b0;
    else
      if( valid_rd_req )
        rd_ptr <= rd_ptr + 1'd1;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    wr_ptr <= '0;
  else
    if( srst_i )
      wr_ptr <= '0;
    else
      if( valid_wr_req )
        wr_ptr <= wr_ptr + 1'd1;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    words_cnt <= '0;
  else
    if( srst_i )
      words_cnt <= '0;
    else
      begin
        case( { valid_wr_req, valid_rd_req } )
          2'b00: words_cnt <= words_cnt; // do nothing 
          2'b01: words_cnt <= words_cnt - 1'd1;
          2'b10: words_cnt <= words_cnt + 1'd1;
          2'b11: words_cnt <= words_cnt; // do nothing
        endcase
      end

assign empty_o = ( words_cnt == '0            );
assign full_o  = ( words_cnt == MAX_WORDS_CNT ); 

true_dual_port_ram_single_clock #(
  .DATA_WIDTH                             ( DATA_W            ),
  .ADDR_WIDTH                             ( ADDR_W            ),
  .REGISTER_OUT                           ( 0                 )
) ram (
  .clk                                    ( clk_i             ),

  // write port
  .addr_a                                 ( wr_ptr            ),
  .data_a                                 ( wr_data_i         ),
  .we_a                                   ( valid_wr_req      ),
  .re_a                                   ( 1'b0              ),
  .q_a                                    (                   ), // unused
  
  // read port
  .addr_b                                 ( rd_ptr            ),
  .data_b                                 ( {{DATA_W}{1'b0}}  ),
  .we_b                                   ( 1'b0              ),
  .re_b                                   ( 1'b1              ),
  .q_b                                    ( rd_data_o         )
);

endmodule
