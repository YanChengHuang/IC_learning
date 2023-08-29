
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
MMS_2num final(.result(result), .select(select), .number0(upper_result), .number1(lower_result));

endmodule

module MMS_2num(result, select, number0, number1);
	input        select;
	input  [7:0] number0;
	input  [7:0] number1;
	output reg[7:0] result;
	begin
		always@ (*)
		begin
			result = number0;
			if(select == 0)
			begin
				if(number0 > number1)
					result = number0;
				else
					result = number1;
			end
			else
			begin
				if(number0 > number1)
					result = number1;
				else
					result = number0;
			end
		end
	end
endmodule
