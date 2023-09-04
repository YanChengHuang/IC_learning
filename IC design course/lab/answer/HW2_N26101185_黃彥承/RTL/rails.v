module rails(clk, reset, data, valid, result);

input        clk;
input        reset;
input  [3:0] data;
output reg  valid;
output reg  result; 

reg [9:0] station_order, B_order, temp;
reg [1:0] state_reg, state_next;
localparam [1:0] IDLE=2'b00, FETCH_FIRST=2'b01, FETCH=2'b10, FINISH=2'b11;
reg valid_w, result_w;
wire [9:0]temp_wire;


always@(posedge clk or posedge reset)
begin
    valid <= valid_w;
    result <= result_w;
    if(reset)begin
        valid <= 1'b0;
        result <= 1'b0;
    end 
    else state_reg <= state_next;
end

always@(data or state_reg)
begin
    case (state_reg)
        IDLE:
        begin
            if(data)    state_next = FETCH_FIRST;
            else    state_next = IDLE;
        end
        FETCH_FIRST:
        begin
            state_next = FETCH;
        end
        FETCH:
        begin
            if(data) state_next = FETCH ;
            else state_next = FINISH;
        end
        default:
        begin 
            state_next = IDLE;
        end
    endcase
end

assign temp_wire = (data !== 4'bx)?((10'b1 << (data-1))-1):10'b0 ;

always@(data or state_reg)
begin
    case (state_reg)
        IDLE:
        begin
            result_w = 1'b1;
            valid_w = 1'b0;
            station_order = 10'b0;
			B_order = 10'b0;
        end
        FETCH_FIRST:
        begin

        end
        FETCH:
        begin
            if((temp_wire > station_order))
                station_order = temp_wire ^ B_order;								
            else
                begin
                    if((temp_wire << 1)+1 >= station_order)    station_order[data-1] = 1'b0;
                    else    result_w = 1'b0;                    
                end
            B_order[(data-1)] = 1'b1;
        end
        default:
        begin
            valid_w = 1'b1;
        end
    endcase
end

endmodule