import hash_table::*;

module data_table( 
  input                clk_i,
  input                rst_i,

  ht_if.slave          ht_in,
  ht_res_if.master     ht_res_out,
  
  head_table_if.master head_table_if,

  // interface to clear [fill with zero] all ram content
  input                clear_ram_run_i,
  output logic         clear_ram_done_o

);

ht_if ht_in_d1( 
  .clk            ( clk_i          ) 
);

localparam D_WIDTH = $bits( ram_data_t );
localparam A_WIDTH = HEAD_PTR_WIDTH;

logic [A_WIDTH-1:0]    wr_addr;
logic [A_WIDTH-1:0]    rd_addr;

ram_data_t             wr_data;
ram_data_t             rd_data;
logic                  wr_en;

logic                  rd_en;

data_table_search_wrapper #( 
  .ENGINES_CNT                            ( 3                 ),
  .RAM_LATENCY                            ( 2                 )
) search_wr (

  .clk_i                                  ( clk_i             ),
  .rst_i                                  ( rst_i             ),
    
  .ht_if                                  ( ht_in             ),

    //ht_res_if.master      ht_res_if,

  .rd_data_i                              ( rd_data           ),

  .rd_addr_o                              ( rd_addr           ),
  .rd_en_o                                ( rd_en             )

);


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
logic [A_WIDTH-1:0] insert_empty_addr;
logic               insert_empty_addr_val;
logic               insert_empty_addr_rd_ack;

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


/*
ht_delay #(
  .DELAY                                  ( 1                 ),
  .PIPELINE_READY                         ( 0                 )
) ht_d1 (
  .clk_i                                  ( clk_i             ),
  .rst_i                                  ( rst_i             ),

  .ht_in                                  ( ht_in             ),
  .ht_out                                 ( ht_in_d1          )

);

assign ht_in_d1.ready = ht_res_out.ready;
*/

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

// synthesis translate_off

clocking cb @( posedge clk_i );
endclocking

task write_to_data_ram( 
  input bit [TABLE_ADDR_WIDTH-1:0] _addr, 
        bit [KEY_WIDTH-1:0]        _key,
        bit [VALUE_WIDTH-1:0]      _value,
        bit [TABLE_ADDR_WIDTH-1:0] _next_ptr,
        bit                        _next_ptr_val 
);
  ram_data_t _wr_data;

  _wr_data.key          = _key;          
  _wr_data.value        = _value;        
  _wr_data.next_ptr     = _next_ptr;     
  _wr_data.next_ptr_val = _next_ptr_val;

  @cb;
  force wr_data = _wr_data;
  force wr_addr = _addr;
  force wr_en   = 1'b0;

  @cb;
  force wr_en   = 1'b1;
  
  @cb;
  force wr_en   = 1'b0;
  
  @cb;
  release wr_data; 
  release wr_addr;
  release wr_en;
endtask                            

// synthesis translate_on

endmodule
