`include "MMS_2num.v"
module MMS_4num(result, select, number0, number1, number2, number3);

input        select;
input  [7:0] number0;
input  [7:0] number1;
input  [7:0] number2;
input  [7:0] number3;
output [7:0] result; 


wire [7:0] upper_result;
wire [7:0] lower_result;	

MMS_2num upper(.result(upper_result), .select(select), .number0(number0), .number1(number1));
MMS_2num lower(.result(lower_result), .select(select), .number0(number2), .number1(number3));
MMS_2num last(.result(result), .select(select), .number0(upper_result), .number1(lower_result));

endmodule

