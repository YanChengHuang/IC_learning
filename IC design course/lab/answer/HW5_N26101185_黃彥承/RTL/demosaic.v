module demosaic(clk, reset, in_en, data_in, wr_r, addr_r, wdata_r, rdata_r, wr_g, addr_g, wdata_g, rdata_g, wr_b, addr_b, wdata_b, rdata_b, done);
input clk;
input reset;
input in_en;
input [7:0] data_in;
output reg wr_r;
output reg [13:0] addr_r;
output reg [7:0] wdata_r;
input [7:0] rdata_r;
output reg wr_g;
output reg [13:0] addr_g;
output reg [7:0] wdata_g;
input [7:0] rdata_g;
output reg wr_b;
output reg [13:0] addr_b;
output reg [7:0] wdata_b;
input [7:0] rdata_b;
output reg done;

localparam [2:0] STORE = 3'd0,
				DEMOSAIC = 3'd1,
                STORE_DE = 3'd2,
                FINISH = 3'd3;

localparam LENGTH = 8'd128;
localparam ONE = 8'd1;

reg [2:0] state_reg, state_next;
reg [13:0] idx;
reg [2:0] sur_count;
reg [9:0] r_sum, g_sum, b_sum;

// sequencial block
always@(posedge clk)
begin
	if(reset)	state_reg <= STORE;
	else 	state_reg <= state_next;
end
wire [1:0] position = {idx[7],idx[0]};

// state control block
always@(*)
begin
    case (state_reg)
        STORE:
        begin
            if(idx == 14'd16383) state_next = DEMOSAIC;
            else state_next = STORE;
        end
        DEMOSAIC:
        begin
            case(position)
                2'b11: state_next = (sur_count== 3'd2)? STORE_DE: DEMOSAIC;
                2'b10: state_next = (sur_count== 3'd4)? STORE_DE: DEMOSAIC;
                2'b01: state_next = (sur_count== 3'd4)? STORE_DE: DEMOSAIC;
                default: state_next = (sur_count== 3'd2)? STORE_DE: DEMOSAIC;
            endcase
        end
        STORE_DE: state_next = (idx == 14'd16383)? FINISH : DEMOSAIC;
		default: state_next = STORE;
    endcase
end
always@(posedge clk or posedge reset)
begin
	if(reset)
    begin
		wr_r <= 1'b0;
        wr_g <= 1'b0;
        wr_b <= 1'b0;
        done <= 1'b0;
        idx <= 14'b0;
        sur_count <= 3'd0;
        r_sum <= 10'd0;
        g_sum <= 10'd0;
        b_sum <= 10'd0;
	end
	else
	begin
        case(state_reg)
        STORE:
        begin
            idx <= idx + 1'b1;
            wr_r <= 1'b0;
            wr_g <= 1'b0;
            wr_b <= 1'b0;
            case(position)
                2'b11: 
                begin
                    addr_g <= idx;
                    wr_g <= 1'b1;
                    wdata_g <= data_in;
                end
                2'b10: 
                begin
                    addr_b <= idx;
                    wr_b <= 1'b1;
                    wdata_b <= data_in;
                end
                2'b01: 
                begin
                    addr_r <= idx;
                    wr_r <= 1'b1;
                    wdata_r <= data_in;
                end
                2'b00:
                begin
                    addr_g <= idx;
                    wr_g <= 1'b1;
                    wdata_g <= data_in;
                end
            endcase
        end
        DEMOSAIC:
        begin
            wr_r <= 1'b0;
            wr_g <= 1'b0;
            wr_b <= 1'b0;
            sur_count <= sur_count + 1'b1;
            
            case(position)
            2'b11: 
            begin
                case(sur_count)
                    0: 
                    begin
                        addr_b <= idx - ONE;
                        addr_r <= idx - LENGTH ;
                    end
                    1:
                    begin
                        addr_b <= idx + ONE;
                        addr_r <= idx + LENGTH;
                        b_sum <= b_sum + rdata_b;
                        r_sum <= r_sum + rdata_r;
                    end
                    2:
                    begin
                        b_sum <= b_sum + rdata_b;
                        r_sum <= r_sum + rdata_r;
                    end
                endcase
            end
            2'b10: 
            begin
                case(sur_count)
                    0: 
                    begin
                        addr_r <= idx - LENGTH - ONE;
                        addr_g <= idx - LENGTH;
                    end
                    1:
                    begin
                        addr_r <= idx - LENGTH + ONE;
                        addr_g <= idx - ONE;
                        r_sum <= r_sum + rdata_r;
                        g_sum <= g_sum + rdata_g;
                    end
                    2:
                    begin
                        addr_r <= idx + LENGTH - ONE;
                        addr_g <= idx + ONE;
                        r_sum <= r_sum + rdata_r;
                        g_sum <= g_sum + rdata_g;
                    end
                    3:
                    begin
                        addr_r <= idx + LENGTH + ONE;
                        addr_g <= idx + LENGTH;
                        r_sum <= r_sum + rdata_r;
                        g_sum <= g_sum + rdata_g;
                    end
                    4:
                    begin
                        r_sum <= r_sum + rdata_r;
                        g_sum <= g_sum + rdata_g;
                    end
                endcase
            end
            2'b01: 
            begin
                case(sur_count)
                    0: 
                    begin
                        addr_b <= idx - LENGTH - ONE;
                        addr_g <= idx - LENGTH;
                    end
                    1:
                    begin
                        addr_b <= idx - LENGTH + ONE;
                        addr_g <= idx - ONE;
                        b_sum <= b_sum + rdata_b;
                        g_sum <= g_sum + rdata_g;
                    end
                    2:
                    begin
                        addr_b <= idx + LENGTH - ONE;
                        addr_g <= idx + ONE;
                        b_sum <= b_sum + rdata_b;
                        g_sum <= g_sum + rdata_g;
                    end
                    3:
                    begin
                        addr_b <= idx + LENGTH + ONE;
                        addr_g <= idx + LENGTH;
                        b_sum <= b_sum + rdata_b;
                        g_sum <= g_sum + rdata_g;
                    end
                    4:
                    begin
                        b_sum <= b_sum + rdata_b;
                        g_sum <= g_sum + rdata_g;
                    end
                endcase
            end
            2'b00:
            begin
                case(sur_count)
                    0: 
                    begin
                        addr_r <= idx - ONE;
                        addr_b <= idx - LENGTH;
                    end
                    1:
                    begin
                        addr_r <= idx + ONE;
                        addr_b <= idx + LENGTH;
                        r_sum <= r_sum + rdata_r;
                        b_sum <= b_sum + rdata_b;
                    end
                    2:
                    begin
                        r_sum <= r_sum + rdata_r;
                        b_sum <= b_sum + rdata_b;
                    end
                endcase
            end
        endcase
        end
        STORE_DE:
        begin
            sur_count <= 3'd0;
            idx <= idx + 1'b1;
            r_sum <= 10'd0;
            g_sum <= 10'd0;
            b_sum <= 10'd0;

            case(position)
                2'b10: 
                begin
                    wr_g <= 1'b1;
                    wr_r <= 1'b1;
                    addr_g <= idx;
                    addr_r <= idx;
                    wdata_g <= g_sum[9:2];
                    wdata_r <= r_sum[9:2];
                end
                2'b01: 
                begin
                    wr_g <= 1'b1;
                    wr_b <= 1'b1;
                    addr_g <= idx;
                    addr_b <= idx;
                    wdata_g <= g_sum[9:2];
                    wdata_b <= b_sum[9:2];
                end
                default:
                begin
                    wr_b <= 1'b1;
                    wr_r <= 1'b1;
                    addr_b <= idx;
                    addr_r <= idx;
                    wdata_b <= b_sum[8:1];
                    wdata_r <= r_sum[8:1];
                end
            endcase
        end
        FINISH: done <= 1'b1;
        endcase
    end
end
endmodule
