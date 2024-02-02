`include "transaction.svh"
`timescale 1ns/1ps
`difine SV_RAND_CHECK(r) \
	do begin\
      if(!(r)) begin\
        $display("%s: %0d  Randomization failed\"%s\"", \
        `__FILE__, `__LINE__, `"r`");\
        $finish;\
      end\
    end while(0)

module tb();
import tb_oponent::*;

initial begin
// RandomTest Rand1;
// Rand1 = new();

Excercise1 Exer1;
Exer1 = new();
  
repeat (10) begin
//    Rand1.randomize();
//    Rand1.display();
Exer1.randomize();
Exer1.display();

end

end

final begin
  $display("This is the end of the test");
end

endmodule: tb