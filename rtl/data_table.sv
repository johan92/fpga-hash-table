import hash_table::*;

module data_table #( 
  parameter KEY_WIDTH        = 32,
  parameter VALUE_WIDTH      = 16,
  parameter BUCKET_WIDTH     = 8,
  parameter TABLE_ADDR_WIDTH = 10
)
(
  input                clk_i,
  input                rst_i,

  ht_if.slave          ht_in,
  ht_res_if.master     ht_res_out,
  
  head_table_if.master head_table_if,

  // interface to clear [fill with zero] all ram content
  input                clear_ram_run_i,
  output logic         clear_ram_done_o

);
localparam HEAD_PTR_WIDTH = TABLE_ADDR_WIDTH;

ht_if #( 
  .KEY_WIDTH      ( KEY_WIDTH      ),
  .VALUE_WIDTH    ( VALUE_WIDTH    ),
  .BUCKET_WIDTH   ( BUCKET_WIDTH   ),
  .HEAD_PTR_WIDTH ( HEAD_PTR_WIDTH )
) ht_in_d1 ( 
  .clk            ( clk_i          ) 
);

typedef struct packed {
  logic [KEY_WIDTH-1:0]      key;
  logic [VALUE_WIDTH-1:0]    value;
  logic [HEAD_PTR_WIDTH-1:0] next_ptr;
  logic                      next_ptr_val;
} ram_data_t; 

localparam D_WIDTH = $bits( ram_data_t );
localparam A_WIDTH = HEAD_PTR_WIDTH;

logic [A_WIDTH-1:0]    wr_addr;
logic [A_WIDTH-1:0]    rd_addr;

ram_data_t             wr_data;
ram_data_t             rd_data;
logic                  wr_en;

// flag for reading from pipelined stage
logic                  back_read;

logic                  rd_en;
logic                  rd_data_val;

assign rd_addr = back_read ? ( rd_data.next_ptr ) : ( ht_in.head_ptr );

assign rd_en   = back_read || ( ht_in.ready && ht_in.valid );

// RAM got 1 tick delay
always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    rd_data_val <= 1'b0;
  else
    rd_data_val <= rd_en;

logic key_match;

assign key_match = ( rd_data.key == ht_in_d1.key );

ht_data_table_state_t state;
ht_data_table_state_t next_state;

always_comb
  begin
    next_state = state;

    // no head on this bucket
    if( !ht_in_d1.head_ptr_val )
      begin
        next_state = READ_NO_HEAD;
      end
    else
      if( key_match )
        begin
          next_state = KEY_MATCH;
        end
      else
        if( !key_match && rd_data.next_ptr_val )
          begin
            next_state = KEY_NO_MATCH_HAVE_NEXT_PTR;
          end
        else
          begin
            next_state = GOT_TAIL;
          end
  end

assign back_read = ( next_state == KEY_NO_MATCH_HAVE_NEXT_PTR );

// ******* Search Data logic *******
/*
  Search algo:
    if( no valid head_ptr )
      SEARCH_NOT_SUCCESS_NO_ENTRY
    else
      if( key and data matched )
        SEARCH_FOUND
      else
        SEARCH_NOT_SUCCESS_NO_ENTRY
*/

// ******* Insert Data logic *******

/*
Insert algo:
  if( no valid head_ptr )
    begin
      goto: get new empty addr
    end
  else
    begin
      start seaching - tring to find data with the same key
      at the end of the search we will be at tail of chain

      if( key matched )
        just update data in this addr, 
        INSERT_SUCCESS_SAME_KEY
    end

  get new empty addr:
    if( no empty addr - table is full )
      INSERT_NOT_SUCCESS_TABLE_IS_FULL
    else
      if( it was no valid head ptr ) 
        begin
          update info about head ptr in head table
          write data in addr, next_ptr is null

          INSERT_SUCCESS
        end
      // there was some data in chain, so, just adding at end of chain
      else
        begin
          write data in addr, next_ptr is null
          update ptr in previous chain addr

          INSERT_SUCCESS
        end
*/

logic       [A_WIDTH-1:0] insert_empty_addr;
logic                     insert_empty_addr_val;
logic                     insert_empty_addr_rd_ack;

logic       [A_WIDTH-1:0] insert_wr_addr;
ram_data_t                insert_wr_data_add_chain;
ram_data_t                insert_wr_data_new_key;
logic                     insert_wr_en;

always_comb
  begin
    insert_wr_data_add_chain              = rd_data;
    
    insert_wr_data_add_chain.next_ptr     = insert_empty_addr;
    insert_wr_data_add_chain.next_ptr_val = 1'b1;
  end

assign insert_wr_data_new_key.key          = ht_d1.key;
assign insert_wr_data_new_key.value        = ht_d1.value;
assign insert_wr_data_new_key.next_ptr     = '0;
assign insert_wr_data_new_key.next_ptr_val = 1'b0;

// ******* Delete Data Logic *******
/*
  Delete algo:

  if( no valid head_ptr )
    DELETE_NOT_SUCCESS_NO_ENTRY
  else
    if( key and data matched )
      begin
        
        clear data in addr
        put addr to empty list 

        if( it's first data in chain ) 
          begin
            // update head ptr in head_table 
            if( next_ptr is NULL )
              head_ptr = NULL
            else
              head_ptr = next_ptr
          end
       else
         if( it's last data in chain )
           begin
             set in previous chain addr next_ptr is NULL
           end
         else
           // we got data in the middle of chain
           begin
             set in previous chain addr next_ptr is ptr of next data
           end

        DELETE_SUCCESS
      end
    else
      begin
        DELETE_NOT_SUCCESS_NO_ENTRY
      end
*/

// ******* Empty ptr store *******
empty_ptr_storage #(
  .A_WIDTH                                ( TABLE_ADDR_WIDTH  )
) empty_ptr_storage (

  .clk_i                                  ( clk_i             ),
  .rst_i                                  ( rst_i             ),
    
  .add_empty_ptr_i                        ( add_empty_ptr_i   ),
  .add_empty_ptr_en_i                     ( add_empty_ptr_en_i),
    
  .next_empty_ptr_rd_ack_i                ( insert_empty_addr_rd_ack ),
  .next_empty_ptr_o                       ( insert_empty_addr        ),
  .next_empty_ptr_val_o                   ( insert_empty_addr_val    )

);



// ******* Clear RAM logic *******
logic               clear_ram_flag;
logic [A_WIDTH-1:0] clear_addr;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    clear_ram_flag <= 1'b0;
  else
    begin
      if( clear_ram_run_i )
        clear_ram_flag <= 1'b1;

      if( clear_ram_done_o )
        clear_ram_flag <= 1'b0;
    end
    
always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    clear_addr <= '0;
  else
    if( clear_ram_run_i )
      clear_addr <= '0;
    else
      if( clear_ram_flag )
        clear_addr <= clear_addr + 1'd1;

assign wr_addr          = ( clear_ram_flag ) ? ( clear_addr ) : ( 'x ); //FIXME
assign wr_data          = ( clear_ram_flag ) ? ( '0         ) : ( 'x );
assign wr_en            = ( clear_ram_flag ) ? ( 1'b1       ) : ( 'x ); 
assign clear_ram_done_o = clear_ram_flag && ( clear_addr == '1 );


ht_delay #(
  .KEY_WIDTH                              ( KEY_WIDTH         ),
  .VALUE_WIDTH                            ( VALUE_WIDTH       ),

  .BUCKET_WIDTH                           ( BUCKET_WIDTH      ),
  .HEAD_PTR_WIDTH                         ( HEAD_PTR_WIDTH    ),

  .DELAY                                  ( 1                 ),
  .PIPELINE_READY                         ( 0                 )
) ht_d1 (
  .clk_i                                  ( clk_i             ),
  .rst_i                                  ( rst_i             ),

  .ht_in                                  ( ht_in             ),
  .ht_out                                 ( ht_in_d1          )

);

assign ht_in_d1.ready = ht_res_out.ready;

true_dual_port_ram_single_clock #( 
  .DATA_WIDTH                             ( D_WIDTH           ), 
  .ADDR_WIDTH                             ( A_WIDTH           ), 
  .REGISTER_OUT                           ( 0                 )
) data_ram (
  .clk                                    ( clk_i             ),

  .addr_a                                 ( rd_addr           ),
  .data_a                                 ( {D_WIDTH{1'b0}}   ),
  .we_a                                   ( 1'b0              ),
  .q_a                                    ( rd_data           ),

  .addr_b                                 ( wr_addr           ),
  .data_b                                 ( wr_data           ),
  .we_b                                   ( wr_en             ),
  .q_b                                    (                   )
);

endmodule
