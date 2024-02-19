interface LCD_if(input bit clk, reset);
	logic [3:0] cmd;
	logic cmd_valid;
	logic [7:0] IROM_Q;
	logic IROM_rd;
	logic[5:0] IROM_A;
	logic IRAM_valid;
	logic[7:0] IRAM_D;
	logic [5:0] IRAM_A;
	logic busy;
	logic done;
  
	clocking cb @(negedge clk);
		output cmd, cmd_valid, IROM_Q;
		input IROM_rd, IROM_A, IRAM_valid, IRAM_D, IRAM_A, busy, done, clk, reset;
	endclocking
  modport TEST (clocking cb);
  
endinterface
