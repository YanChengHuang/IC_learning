`include "tb_component.sv"
`define END_CYCLE 10000
program test(LCD_if.TEST LCDif);
	import tb_component::*;
	Environment env;

	initial begin
		env = new(LCDif, 2);
		env.build();
		env.run();
		env.wrap_up();
    end
	
  
endprogram