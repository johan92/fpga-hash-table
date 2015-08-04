import hash_table::*;

interface ht_task_if #( 
  parameter KEY_WIDTH      = 32,
  parameter VALUE_WIDTH    = 16
)( 
  input clk 
);

logic    [KEY_WIDTH-1:0]    key;
logic    [VALUE_WIDTH-1:0]  value;
ht_cmd_t                    cmd;

logic                       valid;
logic                       ready;

modport master(
  output key,
  output value,
  output cmd,
  output valid,
  input  ready
);

modport slave(
  input  key,
  input  value,
  input  cmd,
  input  valid,
  output ready
);

endinterface
