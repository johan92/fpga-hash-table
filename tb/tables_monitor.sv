//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

import hash_table::*;

module tables_monitor( 
  input                        clk_i,
  input                        rst_i,

  // head_ptr table
  input head_ram_data_t        head_table_wr_data_i,
  input [BUCKET_WIDTH-1:0]     head_table_wr_addr_i,
  input                        head_table_wr_en_i,

  // data table
  input ram_data_t             data_table_wr_data_i,
  input [TABLE_ADDR_WIDTH-1:0] data_table_wr_addr_i,
  input                        data_table_wr_en_i,

  input [TABLE_ADDR_WIDTH-1:0] data_table_rd_addr_i,
  input                        data_table_rd_en_i,

  // empty ptr storage 
  input                        empty_ptr_srst_i,

  input [TABLE_ADDR_WIDTH-1:0] empty_ptr_add_addr_i,
  input                        empty_ptr_add_addr_en_i,

  input [TABLE_ADDR_WIDTH-1:0] empty_ptr_del_addr_i,
  input                        empty_ptr_del_addr_en_i
  
);
localparam BUCKETS_CNT      = 2**BUCKET_WIDTH;
localparam HEAD_TABLE_WORDS = 2**BUCKET_WIDTH;
localparam DATA_TABLE_WORDS = 2**TABLE_ADDR_WIDTH;

head_ram_data_t head_table [HEAD_TABLE_WORDS-1:0];
ram_data_t      data_table [DATA_TABLE_WORDS-1:0];

// reference head and data table
always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    begin
      for( int i = 0; i < HEAD_TABLE_WORDS; i++ )
        begin
          head_table[i] <= '0;
        end
    end
  else
    if( head_table_wr_en_i )
      begin
        head_table[ head_table_wr_addr_i ] <= head_table_wr_data_i; 
      end

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    begin
      for( int i = 0; i < DATA_TABLE_WORDS; i++ )
        begin
          data_table[i] <= '0;
        end
    end
  else
    if( data_table_wr_en_i )
      begin
        data_table[ data_table_wr_addr_i ] <= data_table_wr_data_i; 
      end

// reference empty ptr storage
localparam TABLE_ADDR_CNT = 2**TABLE_ADDR_WIDTH;

logic [TABLE_ADDR_CNT-1:0] empty_ptr_mask;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    empty_ptr_mask <= '0;
  else
    begin
      if( empty_ptr_srst_i )
        empty_ptr_mask <= '0;

      if( empty_ptr_add_addr_en_i )
        empty_ptr_mask[ empty_ptr_add_addr_i ] <= 1'b1;

      if( empty_ptr_del_addr_en_i )
        empty_ptr_mask[ empty_ptr_del_addr_i ] <= 1'b0;
    end

function automatic void check_head_table_equal_ptr( );
  int ptr_cnt [BUCKETS_CNT-1:0];


  // calculating how much ptr exists in head_table
  for( int i = 0; i < HEAD_TABLE_WORDS; i++ )
    begin
      if( head_table[i].ptr_val )
        ptr_cnt[ head_table[i].ptr ] += 1;
    end
 
  for( int i = 0; i < BUCKETS_CNT; i++ )
    begin
      if( ptr_cnt[i] > 1 )
        begin
          $error("failed! bucket_num = %d ptr_cnt = %d", i, ptr_cnt[i] );
        end
    end

endfunction

int data_addr_cnt [DATA_TABLE_WORDS-1:0];

// return 0, if all ok
function automatic int check_one_addr( input bit [BUCKET_WIDTH-1:0]     _bucket_num, 
                                       input bit [TABLE_ADDR_WIDTH-1:0] _addr ); 
  int rez;

  rez = 0;

  if( data_addr_cnt[ _addr ] > 1 ) 
    begin
      $error("ERROR: addr = 0x%x. More than one link to this addr.", _addr );
      rez = -1;
    end

  if( empty_ptr_mask[ _addr ] == 1'b1 )
    begin
      $error("ERROR: addr = 0x%x. This addr is empty, but ptr is val",  _addr );

      rez = -1;
    end

  if( data_table[ _addr ].key[KEY_WIDTH-1:KEY_WIDTH - BUCKET_WIDTH] != _bucket_num )
    begin
      $error("ERROR: addr = 0x%x key=0x%x don't match bucket_num = 0x%x", 
                      _addr, data_table[_addr].key, _bucket_num );

      rez = -1;
    end

  return rez;
endfunction 

function automatic void go_through_all_data( );
  bit [BUCKET_WIDTH-1:0] _bucket_num;

  foreach( data_addr_cnt[i] )
    data_addr_cnt[i] = 0;

  for( int h = 0; h < HEAD_TABLE_WORDS; h++ )
    begin
      bit [TABLE_ADDR_WIDTH-1:0] _data_addr; 

      _bucket_num = h;
      _data_addr  = head_table[h].ptr;

      if( head_table[h].ptr_val )
        begin
          
          data_addr_cnt[ _data_addr ] += 1; 

          if( check_one_addr( _bucket_num, _data_addr ) )
            begin
              return;
            end
          
          while( data_table[ _data_addr ].next_ptr_val )
            begin
              // go on chain
              _data_addr = data_table[ _data_addr ].next_ptr;

              data_addr_cnt[ _data_addr ] += 1; 

              if( check_one_addr( _bucket_num,  _data_addr ) )
                begin
                  return;
                end
            end

        end
    end

endfunction 

// checking "thread"
// do it at negedge to exclude some races
always_ff @( negedge clk_i )
  begin
    // we don't want check when something changing in table...
    if( !head_table_wr_en_i && !data_table_wr_en_i )
      begin
        check_head_table_equal_ptr( );
        go_through_all_data( );
      end
  end

// checking read/write to empty_ptr_storage  
always_ff @( posedge clk_i )
  begin
    if( empty_ptr_add_addr_en_i && empty_ptr_mask[ empty_ptr_add_addr_i ] == 1'b1 )
      begin 
        $error( "ERROR: trying to empty addr = 0x%x, that is already empty!", empty_ptr_add_addr_i );
      end
    
    if( empty_ptr_del_addr_en_i && empty_ptr_mask[ empty_ptr_del_addr_i ] == 1'b0 )
      begin 
        $error( "ERROR: trying to make not empty addr = 0x%x, that is already not empty!", empty_ptr_del_addr_i );
      end
  end

// checking that we don't read from addreses that we think is empty 
always_ff @( posedge clk_i )
  if( data_table_rd_en_i )
    begin
      if( empty_ptr_mask[ data_table_rd_addr_i ] == 1'b1 )
        begin
          $error( "ERROR: reading from empty addr = 0x%x", data_table_rd_addr_i );
        end
    end

endmodule
