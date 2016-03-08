//-----------------------------------------------------------------------------
// Project       : fpga-hash-table
//-----------------------------------------------------------------------------
// Author        : Ivan Shevchuk (github/johan92)
//-----------------------------------------------------------------------------
// Description:
//   Little scoreboard for hashtable:
//   it get commands and dut results, and execute this command on 
//   hash table reference model. if result is not the same - error
//   will be displayed.
//-----------------------------------------------------------------------------

`ifndef _HT_SCOREBOARD_
`define _HT_SCOREBOARD_

class ht_scoreboard;
  
  mailbox #( ht_command_t ) drv2scb; 
  mailbox #( ht_result_t  ) mon2scb; 
  
  ref_hash_table            ref_ht;
  
  typedef enum int unsigned {
    COMMAND_LOST_REORDER,
    
    // ref and dut results not match
    OP_INIT_NOT_MATCH,
    OP_SEARCH_NOT_MATCH,
    OP_INSERT_NOT_MATCH,
    OP_DELETE_NOT_MATCH,

    UNKNOWN_OPCODE,

    // "fake" constant
    ERR_STAT_CNT
  } stat_err_t;
  
  int stat_in_opcode       [ OPCODE_CNT   - 1 : 0 ];
  int stat_out_opcode      [ OPCODE_CNT   - 1 : 0 ];
  int stat_rescode         [ RESCODE_CNT  - 1 : 0 ];
  int stats_err            [ ERR_STAT_CNT - 1 : 0 ];

  `define INC_ERR_STATS( x ) stats_err[ x ] += 1;

  function new( input mailbox #( ht_command_t ) _drv2scb,
                      mailbox #( ht_result_t  ) _mon2scb );
    this.drv2scb = _drv2scb;
    this.mon2scb = _mon2scb;

    this.ref_ht  = new( 2**TABLE_ADDR_WIDTH ); 
  endfunction

  task run( );
    ht_command_t to_dut;
    ht_result_t  from_dut;

    forever
      begin
        mon2scb.get( from_dut );
        drv2scb.get( to_dut   );

        check( to_dut, from_dut );

        calc_stat( to_dut, from_dut );
      end
  endtask
  
  function void calc_stat( input ht_command_t c, ht_result_t r );

    stat_in_opcode  [ c.opcode     ] += 1;
    stat_out_opcode [ r.cmd.opcode ] += 1;
    stat_rescode    [ r.rescode    ] += 1;
    
  endfunction

  function void show_stat( );
    $display("%m:");

    $display( "| %-35s | %10s | %10s |", "OPCODE", "IN", "OUT" );

    for( int i = 0; i < OPCODE_CNT; i++ )
      begin
        $display("| %-35s | %10d | %10d |", ht_opcode_t'(i), stat_in_opcode[i], stat_out_opcode[i] );
      end
    
    $display( " ");

    $display( "| %-35s | %10s |", "RESCODE", "OUT" );
    
    for( int i = 0; i < RESCODE_CNT; i++ )
      begin
        $display("| %-35s | %10d |", ht_rescode_t'(i), stat_rescode[i] );
      end

    $display( " " );
    for( int i = 0; i < ERR_STAT_CNT; i++ )
      begin
        $display("| ERR_%-31s | %10d |", stat_err_t'(i), stats_err[i] );
      end

  endfunction

  // return 1, if no error happend
  function bit test_passed( );
    bit rez = 1'b1;

    for( int i = 0; i < ERR_STAT_CNT; i++ )
      begin
        if( stats_err[i] > 0 )
          rez = 1'b0;
      end

    return rez;
  endfunction 

  function void check( input ht_command_t c, ht_result_t r );
    ht_result_t ref_res;
    
    if( r.cmd != c )
      begin
        `INC_ERR_STATS( COMMAND_LOST_REORDER ) 
        $error("DUT command in result don't match (maybe lost some command or reordering...?)");
        return;
      end

    ref_res = ref_ht.do_command( c );

    case( c.opcode )
      OP_SEARCH:
        begin
          if( ( ref_res.rescode     != r.rescode     ) || 
              ( ref_res.found_value != r.found_value ) )
            begin
              `INC_ERR_STATS( OP_SEARCH_NOT_MATCH )
              $error("Did not in %s: key = 0x%x REF: %s found = 0x%x, DUT: %s found = 0x%x", c.opcode, c.key, ref_res.rescode, ref_res.found_value, r.rescode, r.found_value );
            end
        end

      OP_INIT, OP_INSERT, OP_DELETE:
        begin
          if( ref_res.rescode != r.rescode )
            begin
              case( c.opcode )
                OP_INIT   :  `INC_ERR_STATS ( OP_INIT_NOT_MATCH   )
                OP_INSERT :  `INC_ERR_STATS ( OP_INSERT_NOT_MATCH )
                OP_DELETE :  `INC_ERR_STATS ( OP_DELETE_NOT_MATCH )
              endcase

              $error("Did not in %s REF: %s, DUT: %s", c.opcode, ref_res.rescode, r.rescode );
            end
        end

      default:
        begin
          `INC_ERR_STATS( UNKNOWN_OPCODE )

          $error( "Unknown opcode [%s]!", c.opcode );
        end
    endcase

  endfunction

endclass

`endif
