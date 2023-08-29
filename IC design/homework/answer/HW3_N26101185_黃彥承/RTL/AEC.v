module AEC(clk, rst, ascii_in, ready, valid, result);

// Input signal
input clk;
input rst;
input ready;
input [7:0] ascii_in;

// Output signal
output valid;
output [6:0] result;

// param
reg valid;
reg[6:0] result;
reg [2:0] state_reg, state_next;
reg [4:0] data_arr[0:14], output_arr [0:12], operator_stk [0:3];
reg [6:0] cal_stack [0:3];
reg [3:0] data_idx, read_idx, output_idx, operator_idx, cal_idx, temp_idx;
parameter [2:0] IDLE=3'd0, FETCH=3'd1, PUSH=3'd2, POP=3'd3, MERGE=3'd4, CAL=3'd5, FINISH=3'd6;
wire [4:0] decimal_out;
reg need_left_parenthese;
reg [4:0] i, j;

// ascii to decimel module
ascii_to_decimal a(.ascii_in(ascii_in), .decimal_out(decimal_out));

// read data assignment 
wire[4:0] data, output_w;
wire[3:0] operator_idx_minus_one;
assign operator_idx_minus_one = operator_idx - 4'd1; 
assign data = data_arr[read_idx];
assign output_w = output_arr[temp_idx];

// sequencial block
always@(posedge clk)
begin
    if(rst)begin
        state_reg <= FETCH;
    end 
    else 
    begin
        state_reg <= state_next;
    end
end

wire PUSH_to_POP_cond = (operator_idx && ((data == 5'd19) || (data == 5'd20)) && (operator_stk[operator_idx_minus_one] != 5'd16)) || data == 5'd17 || (data==5'd18 && operator_stk[operator_idx_minus_one] == 5'd18);
// state control block
always@(*)
begin
    case (state_reg)
        IDLE: //0
        begin
            if(decimal_out)    state_next = FETCH;
            else    state_next = IDLE;
        end
        FETCH: //1
        begin
            if(decimal_out == 5'd21) state_next = PUSH;
            else state_next = FETCH;
        end
        PUSH: //2
        begin
            if(PUSH_to_POP_cond) state_next = POP;
            else if(read_idx >= data_idx) state_next = MERGE;
            else state_next = PUSH;
        end
        POP: //3
        begin
            if((operator_stk[operator_idx_minus_one] == 5'd16) && (operator_stk[operator_idx_minus_one-1] == 5'd16)) state_next = PUSH;
            else if(need_left_parenthese) state_next = POP;
            else if(data_idx != read_idx - 4'd1) state_next = PUSH;
            else if(operator_idx == 4'd1) state_next = CAL;
            else state_next = MERGE;
        end
        MERGE: //4
        begin
            if(operator_idx != 4'd1) state_next = MERGE;
            else state_next = CAL;
        end
        CAL: //5
        begin
            if(output_idx == temp_idx + 4'd1) state_next = FINISH;
            else state_next = CAL;
        end
        default: //6
        begin 
            state_next = IDLE;
        end
    endcase
end



//output logic block
always@(posedge clk or posedge rst)
begin
    if(rst)
    begin
        result = 6'b0;
        valid = 1'b0;
        data_idx = 4'b0;
        read_idx = 4'b0;
        output_idx = 4'b0;
        operator_idx = 4'b0;
        cal_idx = 4'b0;
        temp_idx = 4'b0;
        
        for(j = 5'd0; j < 5'd15; j = j + 5'd1) data_arr[j] = 5'b0;
        for(j = 5'd0; j < 5'd13; j = j + 5'd1) output_arr[j] = 5'b0;
        for(j = 5'd0; j < 5'd4; j = j + 5'd1) operator_stk[j] = 5'b0;
        for(j = 5'd0; j < 5'd4; j = j + 5'd1) cal_stack[j] = 7'b0;
    end
    else
    begin
        case (state_reg)
            IDLE:
            begin
                result = 5'b0;
                valid = 1'b0;
                data_idx = 4'b0;
                read_idx = 4'b0;
                output_idx = 4'b0;
                operator_idx = 4'b0;
                cal_idx = 4'b0;
                temp_idx = 4'b0;
                need_left_parenthese = 1'b0;
            end
            FETCH:
            begin
                if(decimal_out != 5'd21)
                begin
                    data_arr[data_idx] = decimal_out;
                    data_idx = data_idx + 4'b1;
                end
                else data_idx = data_idx - 4'b1;
            end
            PUSH:
            begin
            if(data < 5'd16) // is number
                begin
                    output_arr[output_idx] = data;
                    read_idx = read_idx + 4'b1;
                    output_idx = output_idx + 4'b1; 
                end
                else //is not number
                begin
                    if(!operator_idx) // stack is empty place it directly
                    begin
                        operator_stk[operator_idx] = data;
                        operator_idx = operator_idx + 4'd1;
                        read_idx = read_idx + 4'b1;
                    end
                    else
                    begin
                        case (data)
                            5'd18: // rep *
                                begin
                                    if(operator_stk[operator_idx_minus_one] != 5'd18)
                                    begin
                                        operator_stk[operator_idx] = data;
                                        operator_idx = operator_idx + 4'd1;
                                        read_idx = read_idx + 4'b1;
                                    end
                                end
                            5'd16: // rep (
                                begin
                                    operator_stk[operator_idx] = data;
                                    operator_idx = operator_idx + 4'd1;
                                    read_idx = read_idx + 4'b1;
                                end
                            5'd17: // rep )
                                begin
                                    need_left_parenthese = 1'b1;
                                    read_idx = read_idx + 4'b1;
                                end
                            default: // + or -
                                begin
                                    if(operator_stk[operator_idx_minus_one] == 5'd16)
                                    begin
                                        operator_stk[operator_idx] = data;
                                        operator_idx = operator_idx + 4'd1;
                                        read_idx = read_idx + 4'b1;
                                    end
                                   
                                end 
                        endcase
                    end
                end
            end
            POP:
            begin
                if(operator_stk[operator_idx_minus_one] == 5'd16)
                begin
                    operator_idx = operator_idx_minus_one; // rep (               
                end
                else if(operator_stk[operator_idx_minus_one-1] == 5'd16) 
                begin
                    need_left_parenthese = 1'b0; // rep (    
                    output_arr[output_idx] = operator_stk[operator_idx_minus_one];
                    output_idx = output_idx + 4'd1;
                    operator_idx = operator_idx_minus_one;           
                end
                else
                begin
                    output_arr[output_idx] = operator_stk[operator_idx_minus_one];
                    output_idx = output_idx + 4'd1;
                    operator_idx = operator_idx_minus_one;
                end
            end
            MERGE:
            begin
                output_arr[output_idx] = operator_stk[operator_idx_minus_one];
                operator_idx = operator_idx_minus_one;
                output_idx = output_idx + 4'd1;
            end
            CAL:
            begin
                if(output_w < 5'd16)
                begin
                    cal_stack[cal_idx] = output_w;
                    cal_idx = cal_idx + 4'd1;         
                end
                else
                begin
                    case(output_w)
                        5'd18: cal_stack[cal_idx-2] = cal_stack[cal_idx-2] * cal_stack[cal_idx-1];
                        5'd19: cal_stack[cal_idx-2] = cal_stack[cal_idx-2] + cal_stack[cal_idx-1];
                        default: cal_stack[cal_idx-2] = cal_stack[cal_idx-2] - cal_stack[cal_idx-1];
                    endcase
                    cal_idx = cal_idx - 4'd1;
                end
                temp_idx = temp_idx + 4'd1;
            end
            FINISH:
            begin
                result = cal_stack[cal_idx - 4'd1];
                valid = 1'b1;
            end
            default:
            begin
                result = 7'b0;
                valid = 1'b0;
            end
        endcase
    end
    
end
endmodule

