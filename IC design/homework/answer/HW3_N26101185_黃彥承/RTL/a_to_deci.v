module ascii_to_decimal(ascii_in, decimal_out);

input [7:0]  ascii_in;
output reg[4:0] decimal_out;
always @(*)
begin
    case(ascii_in)
    8'd48: decimal_out = 5'd0; 
    8'd49: decimal_out = 5'd1; 
    8'd50: decimal_out = 5'd2; 
    8'd51: decimal_out = 5'd3; 
    8'd52: decimal_out = 5'd4; 
    8'd53: decimal_out = 5'd5; 
    8'd54: decimal_out = 5'd6; 
    8'd55: decimal_out = 5'd7; 
    8'd56: decimal_out = 5'd8; 
    8'd57: decimal_out = 5'd9; 
    8'd97: decimal_out = 5'd10; 
    8'd98: decimal_out = 5'd11; 
    8'd99: decimal_out = 5'd12; 
    8'd100: decimal_out = 5'd13; 
    8'd101: decimal_out = 5'd14; 
    8'd102: decimal_out = 5'd15; 
    8'd40: decimal_out = 5'd16; // rep (
    8'd41: decimal_out = 5'd17; // rep )
    8'd42: decimal_out = 5'd18; // rep *
    8'd43: decimal_out = 5'd19; // rep +
    8'd45: decimal_out = 5'd20; // rep -
    8'd61: decimal_out = 5'd21; // rep =
    default: decimal_out = 5'd0;
    endcase
end
endmodule