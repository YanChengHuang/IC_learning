`include "./MMS_4num.v"

module MMS_8num(result, select, number0, number1, number2, number3, number4, number5, number6, number7);

input        select;
input  [7:0] number0;
input  [7:0] number1;
input  [7:0] number2;
input  [7:0] number3;
input  [7:0] number4;
input  [7:0] number5;
input  [7:0] number6;
input  [7:0] number7;
output [7:0] result; 

wire [7:0] upper_result, lower_result;



	
MMS_4num upper(.result(upper_result), .select(select), .number0(number0), .number1(number1), .number2(number2), .number3(number3));
MMS_4num lower(.result(lower_result), .select(select), .number0(number4), .number1(number5), .number2(number6), .number3(number7));
MMS_2num final(.result(result), .select(select), .number0(upper_result), .number1(lower_result));


endmodule