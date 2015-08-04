// Quartus II Verilog Template
// True Dual Port RAM with single clock

module true_dual_port_ram_single_clock
#(parameter DATA_WIDTH=8, parameter ADDR_WIDTH=6, parameter REGISTER_OUT = 1)
(
	input [(DATA_WIDTH-1):0] data_a, data_b,
	input [(ADDR_WIDTH-1):0] addr_a, addr_b,
	input we_a, we_b, clk,
	output reg [(DATA_WIDTH-1):0] q_a, q_b
);

	// Declare the RAM variable
	reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];
        reg [DATA_WIDTH-1:0] pre_q_a;
        reg [DATA_WIDTH-1:0] pre_q_b;

        initial
          begin
            for( int i = 0; i < 2**ADDR_WIDTH; i++ )
              begin
                ram[i] = '0;
              end
          end

	// Port A 
	always @ (posedge clk)
	begin
		if (we_a) 
		begin
			ram[addr_a] <= data_a;
			pre_q_a <= data_a;
		end
		else 
		begin
			pre_q_a <= ram[addr_a];
		end 
	end 

	// Port B 
	always @ (posedge clk)
	begin
		if (we_b) 
		begin
			ram[addr_b] <= data_b;
			pre_q_b <= data_b;
		end
		else 
		begin
			pre_q_b <= ram[addr_b];
		end 
	end

        generate
          if( REGISTER_OUT )
            begin
              always @( posedge clk )
                begin
                  q_a <= pre_q_a;
                  q_b <= pre_q_b;
                end
            end
          else
            begin
              assign q_a = pre_q_a;
              assign q_b = pre_q_b;
            end
        endgenerate

// synthesis translate_off

// we should do not write to the same address at the same tick
// from different ports
assert property(
  @( posedge clk )
   ( ( we_a && we_b && ( addr_a == addr_b ) ) == 1'b0 )
);

// synthesis translate_on
endmodule
