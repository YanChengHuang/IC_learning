`include "tb_component.sv"
`define END_CYCLE 10000
program test(LCD_if.TEST LCDif);
	import tb_component::*;
	// Transaction tran1;
	Generator gen;
	Driver drv;
	mailbox gen2drv;
	event drv2gen;
// 	virtual LCD_if.TEST LCDifTEST;
	initial begin
      gen2drv = new(1);
      gen = new(gen2drv, drv2gen, 2);
      	drv = new(gen2drv, drv2gen, LCDif);
		fork
			gen.run();
			drv.run();
        join_none
	end
	initial begin
    	#`END_CYCLE $finish;
    end
	
  
endprogram