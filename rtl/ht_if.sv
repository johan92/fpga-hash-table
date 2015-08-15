import hash_table::*;

interface ht_if( 
  input clk 
);

logic  [KEY_WIDTH-1:0]      key;
logic  [VALUE_WIDTH-1:0]    value;
ht_opcode_t                 opcode;

logic  [BUCKET_WIDTH-1:0]   bucket;

logic  [HEAD_PTR_WIDTH-1:0] head_ptr;
logic                       head_ptr_val;

logic                       valid;
logic                       ready;

modport master(
  output key,
  output value,
  output opcode,
  output bucket,
  output head_ptr,
  output head_ptr_val,
  output valid,
  input  ready
);

modport slave(
  input  key,
  input  value,
  input  opcode,
  input  bucket,
  input  head_ptr,
  input  head_ptr_val,
  input  valid,
  output ready
);

endinterface
