//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------

`ifndef _HT_INNER_SCOREBOARD_
`define _HT_INNER_SCOREBOARD_

class ht_inner_scoreboard;

  virtual head_table_if        _head_t_if;
  virtual data_table_if        _data_t_if;
  virtual empty_ptr_storage_if _eps_if;

  localparam BUCKETS_CNT      = 2**BUCKET_WIDTH;
  localparam HEAD_TABLE_WORDS = 2**BUCKET_WIDTH;
  localparam DATA_TABLE_WORDS = 2**TABLE_ADDR_WIDTH;

  head_ram_data_t head_table    [HEAD_TABLE_WORDS-1:0];
  ram_data_t      data_table    [DATA_TABLE_WORDS-1:0];
  int             data_addr_cnt [DATA_TABLE_WORDS-1:0];

  localparam TABLE_ADDR_CNT = 2**TABLE_ADDR_WIDTH;

  logic [TABLE_ADDR_CNT-1:0] empty_ptr_mask;
  
  function new( input virtual head_table_if         _head_table_if,
                      virtual data_table_if         _data_table_if,
                      virtual empty_ptr_storage_if  _eps_if
                    ); 

    this._head_t_if = _head_table_if;
    this._data_t_if = _data_table_if;
    this._eps_if    = _eps_if;

  endfunction
  
  task run( );
    fork
      head_table_thread( );
      data_table_thread( );
      eps_thread( );
    join
  endtask 

  task head_table_thread( );
    forever
      begin
        @( _head_t_if.cb )

        if( _head_t_if.cb.wr_en )
          head_table[ _head_t_if.wr_addr ] = _head_t_if.wr_data;
        
      end
  endtask

  task data_table_thread( );
    forever
      begin

        @( _data_t_if.cb )

        if( _data_t_if.cb.wr_en )
          begin
            data_table[ _data_t_if.cb.wr_addr ] = _data_t_if.cb.wr_data;
            do_tables_check( );
          end

        if( _data_t_if.cb.rd_en )
          begin
            // checking that we don't read from addreses that we think is empty 
            if( empty_ptr_mask[ _data_t_if.cb.rd_addr ] == 1'b1 )
              begin
                $error( "ERROR: reading from empty addr = 0x%x", _data_t_if.cb.rd_addr );
              end

          end

      end
  endtask

  task eps_thread( );
    forever
      begin
        @( _eps_if.cb )

        if( _eps_if.cb.srst )
          begin
            empty_ptr_mask = '0;
          end

        if( _eps_if.cb.add_empty_ptr_en )
          begin
            if( empty_ptr_mask[ _eps_if.cb.add_empty_ptr ] == 1'b1 )
              begin
                $error( "ERROR: trying to empty addr = 0x%x, that is already empty!", 
                                                        _eps_if.cb.add_empty_ptr );
              end

            empty_ptr_mask[ _eps_if.cb.add_empty_ptr ] = 1'b1;
          end

        if( _eps_if.cb.next_empty_ptr_rd_ack )
          begin
            if( empty_ptr_mask[ _eps_if.cb.next_empty_ptr ] == 1'b0 )
              begin
                $error( "ERROR: trying to make not empty addr = 0x%x, that is already not empty!", 
                             _eps_if.cb.next_empty_ptr );
              end
            
            empty_ptr_mask[ _eps_if.cb.next_empty_ptr ] = 1'b0;
          end

      end
  endtask

  function automatic do_tables_check( );
    check_head_table_equal_ptr( );
    go_through_all_data( );
  endfunction 

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

endclass

`endif
