import hash_table::*;

interface ht_cmd_if( 
  input clk 
);

ht_command_t                cmd;
logic                       valid;
logic                       ready;

modport master(
  output cmd,
  output valid,
  input  ready
);

modport slave(
  input  cmd,
  input  valid,
  output ready
);

endinterface
