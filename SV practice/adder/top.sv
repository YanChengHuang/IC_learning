`timescale 1ns/10ps

module top();
// logic  tp_sel;
// logic  tp_n0;
// logic  tp_n1;
// logic  tp_res;
bit clk;
// int fa[5];
always #50 clk = ~clk;
MMS_if MMSif(clk);
MMS_2num MMS1(.result(MMSif.res), .select(MMSif.sel), .number0(MMSif.num0), .number1(MMSif.num1));
tb tb1(MMSif.TEST);
endmodule: top