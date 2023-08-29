module rails(clk, reset, data, valid, result);

input        clk;
input        reset;
input  [3:0] data;
output reg  valid;
output reg  result; 
reg [3:0] data_arr [0:9];
reg [9:0] station_order, B_order, temp_wire;
reg [2:0] state_reg, state_next;
reg [3:0] train_num, train_idx, read_idx, train;
parameter [2:0] IDLE=3'd0, FETCH_FIRST=3'd1, FETCH=3'd2, CAL=3'd3, FINISH=3'd4;
// wire [9:0]temp_wire;
integer i;

always@(posedge clk)
begin 
    if(reset)begin
        state_reg <= FETCH_FIRST;
    end
    else 
    begin
        state_reg <= state_next;
    end
end

always@(*)
begin
    case (state_reg)
        IDLE:
        begin
            // if(data)    state_next = FETCH_FIRST;
            // else    state_next = IDLE;
            state_next = FETCH_FIRST;
        end
        FETCH_FIRST:
        begin
            state_next = FETCH;
        end
        FETCH:
        begin
            if(train_idx < train_num - 1) state_next = FETCH ;
            else state_next = CAL;
        end
        CAL:
            if(read_idx < train_num-1) state_next = CAL;
            else state_next = FINISH;
        default:
        begin 
            state_next = IDLE;
        end
    endcase
end

// assign temp_wire = (data)?((10'b1 << (data-1))-1):10'b0 ;

always@(posedge clk or posedge reset)
begin
    if(reset)
    begin
        result = 1'b1;
        valid = 1'b0;
        station_order = 10'b0;
        B_order = 10'b0;
        train_num = 4'b0;
        train_idx = 4'b0;
        read_idx = 4'b0;
        for(i = 0; i < 10; i = i + 1) data_arr[i] = 4'b0;
    end
    else
    begin
        case (state_reg)
            IDLE:
            begin
                result = 1'b1;
                valid = 1'b0;
                station_order = 10'b0;
                B_order = 10'b0;
                train_num = 4'b0;
                train_idx = 4'b0;
                read_idx = 4'b0;
                for(i = 0; i < 10; i = i + 1) data_arr[i] = 4'b0;
            end
            FETCH_FIRST:
            begin
                train_num = data;
            end
            FETCH:
            begin
                data_arr[train_idx] = data;
                train_idx = train_idx + 4'b1;
            end
            CAL:
            begin
                train = data_arr[read_idx];
                read_idx = read_idx + 1;
                temp_wire = (10'b1 << (train-1))-1;
                if((temp_wire > station_order))
                    station_order = temp_wire ^ B_order;								
                else
                begin
                    if((temp_wire << 1)+1 >= station_order)    station_order[train-1] = 1'b0;
                    else    result = 1'b0;                    
                end
                B_order[(train-1)] = 1'b1;
            end
            default:
            begin
                valid = 1'b1;
            end
        endcase
    end
end

endmodule