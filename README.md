fpga-hash-table
===============

Hash table implementation on Verilog ( SystemVerilog ).
Collision resolution made by linked list of keys, that fall in one bucket.

Goal:
  * module should resolve collision by himself
  * max SEARCH throughput: can take SEARCH operation at each cycle (if no collision happend)

Assumptions:
  * DELETE and INSERT operations can take a long time
  * collision resolution for SEARCH can take a long time (due to jumping on linked list)

It got two interfaces (Avalon-ST style):
  * ht\_cmd\_in - input interface - for sending commands ( SEARCH, INSERT, DELETE )
  * ht\_res\_out - output interface - result for each command
