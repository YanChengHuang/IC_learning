module rails(clk, reset, data, valid, result);

input        clk;
input        reset;
input  [3:0] data;
output reg  valid;
output reg  result; 

reg [3:0] left_train_num, temp_data;
reg [9:0] station_order, B_order, temp;

/*
	Write Your Design Here ~
*/

always@(posedge clk or posedge reset)
begin
	if(reset)
		begin
			result = 1'b0;
			valid = 1'b0;
			left_train_num = 4'b0;
			station_order = 10'b0;
		end
	else
		begin
			if((temp_data === 4'hx) && (data !== 4'hx))
				begin
					valid = 1'b0;
					left_train_num = data;
					station_order = 10'b0;
					B_order = 10'b0;
				end	
			else
				begin
					if(!left_train_num)
						begin
							result = 1'b1;
							valid = 1'b1;
						end
					else
						begin
							temp = 10'b0;
							temp[data-1] = 1'b1;
							temp = temp -1;
							if((temp > station_order))
								station_order = temp ^ B_order;								
							else
								begin
									if((temp << 1)+1 >= station_order)
										station_order[data-1] = 1'b0;
									else
										begin 
											result = 1'b0;
											valid = 1'b1;
										end
								end
							left_train_num = left_train_num-1;
							B_order[(data-1)] = 1'b1;
						end		
				end	
			temp_data = data;
		end
end 


endmodule