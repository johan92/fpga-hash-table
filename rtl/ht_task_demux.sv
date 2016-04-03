//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

import hash_table::*;

module ht_task_demux #(
  parameter DIR_CNT = 4
) (
  input     ht_pdata_t      pdata_in_i,
  input                     pdata_in_valid_i,
  output    logic           pdata_in_ready_o,

  input                     task_ready_i       [DIR_CNT-1:0],
  input                     task_processing_i  [DIR_CNT-1:0],
  output    ht_pdata_t      task_data_o        [DIR_CNT-1:0],
  output    logic           task_valid_o       [DIR_CNT-1:0]

);

// FIXME: do it without it in `for` cycle or something like that
localparam INIT_   = 0;
localparam SEARCH_ = 1;
localparam INSERT_ = 2;
localparam DELETE_ = 3;

ht_pdata_t task_w;

assign task_w = pdata_in_i;

genvar g;
generate
  for( g = 0; g < DIR_CNT; g++ )
    begin
      assign task_data_o[g] = task_w; 
    end
endgenerate

always_comb
  begin
    pdata_in_ready_o = 1'b1;
    
    task_valid_o[ INIT_   ] = pdata_in_valid_i && ( task_w.cmd.opcode == OP_INIT   );
    task_valid_o[ SEARCH_ ] = pdata_in_valid_i && ( task_w.cmd.opcode == OP_SEARCH );
    task_valid_o[ INSERT_ ] = pdata_in_valid_i && ( task_w.cmd.opcode == OP_INSERT );
    task_valid_o[ DELETE_ ] = pdata_in_valid_i && ( task_w.cmd.opcode == OP_DELETE );
    
    case( task_w.cmd.opcode )
      OP_INIT:
        begin
          if( task_processing_i[ SEARCH_ ] || task_processing_i[ INSERT_ ] || 
              task_processing_i[ DELETE_ ] )
              begin
                pdata_in_ready_o    = 1'b0;
                task_valid_o[ INIT_ ] = 1'b0;
              end
          else
            begin
              pdata_in_ready_o = task_ready_i[ INIT_ ];
              //pdata_in_ready_o = 1'b1; // task_ready_i[ INIT_ ];
            end
        end

      OP_SEARCH:
        begin
          if( task_processing_i[ INIT_   ] || task_processing_i[ INSERT_ ] || 
              task_processing_i[ DELETE_ ] )
            begin
              pdata_in_ready_o      = 1'b0;
              task_valid_o[ SEARCH_ ] = 1'b0;
            end
          else
            begin
              pdata_in_ready_o = task_ready_i[ SEARCH_ ];
            end
        end

      OP_INSERT:
        begin
          if( task_processing_i[ INIT_   ] || task_processing_i[ SEARCH_ ] || 
              task_processing_i[ DELETE_ ] )
            begin
              pdata_in_ready_o      = 1'b0;
              task_valid_o[ INSERT_ ] = 1'b0;
            end
          else
            pdata_in_ready_o = task_ready_i[ INSERT_ ];
        end

      OP_DELETE:
        begin
          if( task_processing_i[ INIT_   ] || task_processing_i[ SEARCH_ ] || 
              task_processing_i[ INSERT_ ] )
            begin
              pdata_in_ready_o      = 1'b0;
              task_valid_o[ DELETE_ ] = 1'b0;
            end
          else
            pdata_in_ready_o = task_ready_i[ DELETE_ ];
        end

      default: 
        begin
          pdata_in_ready_o = 1'b1;
        end
    endcase
  end

endmodule
