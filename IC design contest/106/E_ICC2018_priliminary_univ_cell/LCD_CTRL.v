module LCD_CTRL(clk, reset, cmd, cmd_valid, IROM_Q, IROM_rd, IROM_A, IRAM_valid, IRAM_D, IRAM_A, busy, done);
input clk;
input reset;
input [3:0] cmd;
input cmd_valid;
input [7:0] IROM_Q;
output reg IROM_rd;
output reg [5:0] IROM_A;
output reg IRAM_valid;
output reg [7:0] IRAM_D;
output reg [5:0] IRAM_A;
output reg busy;
output reg done;

localparam [3:0] FETCH_AND_STORE=4'd0, WAIT_CMD=4'd1, PROCESS=4'd2,FINISH=4'd3;
localparam ONE = 1'b1;
reg [3:0] state_reg, state_next;
reg [5:0] idx;
wire [7:0] max, min;
reg [7:0] buffer [0:63];
reg [5:0] buffer_idx;



// sequencial block
always@(posedge clk)
begin
	if(reset)begin
		state_reg <= FETCH_AND_STORE;
	end 
	else 
	begin
		state_reg <= state_next;
	end
end

// state control block
always@(*)
begin
    case (state_reg)
        FETCH_AND_STORE:
        begin
            if(IROM_A==6'd63 && IROM_rd) state_next = WAIT_CMD;
            else state_next = FETCH_AND_STORE;
        end 
        WAIT_CMD: 
        begin
            if(cmd) state_next = PROCESS;
            else  state_next = WAIT_CMD;     
        end 
        PROCESS:
        begin
            case(cmd)
            4'd1,4'd2,4'd3,4'd4,4'd5,4'd6,4'd7,4'd8,4'd9,4'd10,4'd11: state_next = WAIT_CMD;
            default: 
            begin
                if(buffer_idx == 6'd63 && IRAM_valid) state_next = FINISH;
                else state_next = PROCESS;
            end
            endcase
        end
        default: state_next = FETCH_AND_STORE;
    endcase
end

wire[5:0] left_up = {idx[5:3]-ONE,idx[2:0]-ONE};
wire[5:0] right_up = {idx[5:3]-ONE,idx[2:0]};
wire[5:0] left_down = {idx[5:3],idx[2:0]-ONE};
wire[5:0] right_down =  {idx[5:3],idx[2:0]};
wire[11:0] average = ((buffer[left_up] + buffer[right_up]) + (buffer[left_down] + buffer[right_down]))>>2;

MMS_4num a(.result(max), .select(1'b0), .number0(buffer[left_up]), .number1(buffer[right_up]), .number2(buffer[left_down]), .number3(buffer[right_down]));
MMS_4num b(.result(min), .select(1'b1), .number0(buffer[left_up]), .number1(buffer[right_up]), .number2(buffer[left_down]), .number3(buffer[right_down]));

//output logic block
always@(posedge clk or posedge reset)
begin
    if(reset)
    begin 
		IROM_rd <= 1'b0;
        IROM_A <= 6'd63;
        IRAM_A <= 6'd63;
        IRAM_valid <= 1'b0;
        busy <= 1'b1;
        done <= 1'b0;
        idx <= {2{3'b100}};
        buffer_idx <= 6'd63;
	end
	else
    begin
        case(state_reg)
            FETCH_AND_STORE:
            begin
                IROM_rd <= 1'b1;
                IROM_A <= IROM_A + ONE;           
                buffer[IROM_A] <= IROM_Q;
            end
            WAIT_CMD: busy <= !busy; 
            PROCESS:
            begin
                busy <= 1'b1;
                case(cmd)
                    4'd0:
                    begin
                        IRAM_valid <= 1'b1;
                        buffer_idx <= buffer_idx + ONE;
                        IRAM_A <= buffer_idx;
                        IRAM_D <= buffer[buffer_idx];
                    end
                    // shift up
                    4'd1: if(idx[5:3]!=3'd1) idx[5:3] <= idx[5:3] - ONE; 
                    // shift down
                    4'd2: if(idx[5:3]!=3'd7) idx[5:3] <= idx[5:3] + ONE; 
                    // shift left
                    4'd3: if(idx[2:0]!=3'd1) idx[2:0] <= idx[2:0] - ONE;
                    // shift right
                    4'd4: if(idx[2:0]!=3'd7) idx[2:0] <= idx[2:0] + ONE; 
                    // max
                    4'd5: 
                    begin
                        buffer[left_up] <= max;
                        buffer[right_up] <= max;
                        buffer[left_down] <= max;
                        buffer[right_down] <= max;
                    end
                    4'd6: // min
                    begin
                        buffer[left_up] <= min;
                        buffer[right_up] <= min;
                        buffer[left_down] <= min;
                        buffer[right_down] <= min;
                    end
                    4'd7: // average
                    begin
                        buffer[left_up] <= average;
                        buffer[right_up] <= average;
                        buffer[left_down] <= average;
                        buffer[right_down] <= average;
                    end          
                    4'd8: // counterclock rotation
                    begin
                        buffer[left_up] <= buffer[right_up];
                        buffer[right_up] <= buffer[right_down];
                        buffer[left_down] <= buffer[left_up];
                        buffer[right_down] <= buffer[left_down];
                    end                  
                    4'd9: // clockwise rotation
                    begin
                        buffer[left_up] <= buffer[left_down];
                        buffer[right_up] <= buffer[left_up];
                        buffer[left_down] <= buffer[right_down];
                        buffer[right_down] <= buffer[right_up];
                    end   
                    4'd10:// mirror X
                    begin
                        buffer[left_up] <= buffer[left_down];
                        buffer[right_up] <= buffer[right_down];
                        buffer[left_down] <= buffer[left_up];
                        buffer[right_down] <= buffer[right_up];
                    end  
                    4'd11:// mirror Y 
                    begin
                        buffer[left_up] <= buffer[right_up];
                        buffer[right_up] <= buffer[left_up];
                        buffer[left_down] <= buffer[right_down];
                        buffer[right_down] <= buffer[left_down];
                    end  
                endcase
            end
            FINISH: done <= 1'b1;   
        endcase
    end
end
endmodule
