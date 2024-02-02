`include "tb.svh"

module top();
	parameter t_reset = `CYCLE*2;
	bit clk, reset;
	// instantiate interface
	LCD_if LCDif(clk, reset);
	// instantiate DUT
	LCD_CTRL DUT(.clk(LCDif.clk),
				.reset(LCDif.reset), 
				.cmd(LCDif.cmd), 
				.cmd_valid(LCDif.cmd_valid), 
				.IROM_rd(LCDif.IROM_rd), 
				.IROM_A(LCDif.IROM_A), 
				.IROM_Q(LCDif.IROM_Q), 
				.IRAM_valid(LCDif.IRAM_valid), 
				.IRAM_D(LCDif.IRAM_D), 
				.IRAM_A(LCDif.IRAM_A),
				.busy(LCDif.busy), 
				.done(LCDif.done));
	// instantiate Tb
	test t1 (LCDif.TEST);


	initial begin
		$dumpfile("dump.vcd");
		$dumpvars;
		clk = 1'b0;
	end

	always begin #(`CYCLE/2) clk = ~clk; end

	initial begin
    reset = 1'b0;
	@(negedge clk)  reset = 1'b1;
   	#t_reset        reset = 1'b0;  
  end
endmodule

// module DUT_communicator()

// endmodule

