program test(LCD_if.TEST LCDif);
	import tb_component::*;
	Environment env;
	initial begin
		// generate 20 trans
      	env = new(LCDif, 20);
		env.build();
		env.run();
		env.wrap_up();
    end
endprogram