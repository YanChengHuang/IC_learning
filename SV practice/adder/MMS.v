module MMS_2num(result, select, number0, number1);
    input        select;
	input  [7:0] number0;
	input  [7:0] number1;
	output reg[7:0] result;
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
endmodule