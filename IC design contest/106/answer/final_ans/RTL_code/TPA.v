module TPA(clk, reset_n, 
	   SCL, SDA, 
	   cfg_req, cfg_rdy, cfg_cmd, cfg_addr, cfg_wdata, cfg_rdata);
input 		clk; 
input 		reset_n;
// Two-Wire Protocol slave interface 
input 		SCL;  
inout		SDA;

// Register Protocal Master interface 
input		cfg_req;
output reg	cfg_rdy;
// cfg_cmd=1 write, cfg_cmd=0 read
input		cfg_cmd;
input	[7:0]	cfg_addr;
input	[15:0]	cfg_wdata;
output	reg [15:0]  cfg_rdata;

reg	[15:0] Register_Spaces	[0:255];

localparam [3:0] IDLE=4'd0, RIM_set=4'd1, RIM_read=4'd2, RIM_write=4'd3, TWP_set=4'd4, TWP_gaddr=4'd5, TWP_wait_read=4'd6, TWP_read_set=4'd7, TWP_read_fetch=4'd8, TWP_read=4'd9, TWP_read_finish=4'd10, TWP_write_fetch=4'd11, TWP_write=4'd12;
reg [3:0] state_RIM, RIM_next, state_TWP, TWP_next;
reg TWP_wr, TWP_first, RIM_first;
reg [2:0] TWP_addr_idx;
reg [7:0] TWP_addr;
reg [3:0] TWP_data_idx;
reg TWP_wait_count, SDA_reg;
reg [15:0] TWP_read_data;

// ===== Coding your RTL below here ================================= 

// sequencial block
always@(posedge clk)
begin
	if(!reset_n) 
    begin
        state_RIM <= IDLE;
        state_TWP <= IDLE;
    end
	else 
    begin
        state_RIM <= RIM_next;
        state_TWP <= TWP_next;
    end
end

// state control block
always@(*)
begin
    // RIM part
    case(state_RIM)
        IDLE:
        begin
            if(cfg_req) RIM_next = RIM_set;
            else RIM_next = IDLE;
        end
        RIM_set:
        begin
            if(cfg_cmd) RIM_next = RIM_write;
            else RIM_next = RIM_read;
        end
        RIM_write: RIM_next = IDLE;
        RIM_read: RIM_next = IDLE;
        default: RIM_next = IDLE; 
	endcase
    // TWP part
    case(state_TWP)
    IDLE:
    begin
        if(!SDA)
        begin
            if(RIM_next == RIM_set) TWP_next = IDLE;
            else TWP_next = TWP_set;
        end
        else TWP_next = IDLE;
    end
    TWP_set: TWP_next = TWP_gaddr;
    TWP_gaddr:
    begin
        if(TWP_addr_idx == 3'd7)
        begin
            if(TWP_wr) TWP_next = TWP_write;
            else TWP_next = TWP_wait_read;
        end
        else TWP_next = TWP_gaddr;
    end
    TWP_wait_read:
    begin
        if(TWP_wait_count) TWP_next = TWP_read_set;
        else TWP_next = TWP_wait_read;
    end
    TWP_read_set: TWP_next = TWP_read_fetch;
    TWP_read_fetch: TWP_next = TWP_read;
    TWP_read:
    begin
        if(TWP_data_idx == 4'd15) TWP_next = IDLE;
        else TWP_next = TWP_read;
    end
    TWP_write:
    begin
        if(TWP_data_idx == 4'd15) TWP_next = TWP_write_fetch;
        else TWP_next = TWP_write;
    end
    TWP_write_fetch: TWP_next = IDLE;
    default: TWP_next = IDLE;
    endcase
end

assign SDA=(state_TWP == TWP_read) ? TWP_read_data[TWP_data_idx] : 
           (state_TWP == TWP_wait_read) ? 1'b1 :
           (state_TWP == TWP_read_fetch) ? 1'b0 : SDA_reg;

//output logic block
always@(posedge clk or negedge reset_n)
begin
    if(!reset_n)
    begin 
		cfg_rdy <= 1'b0;
        TWP_addr_idx <= 3'b0;
        TWP_data_idx <= 4'b0;
        TWP_wait_count <= 1'b0;
        SDA_reg <= 1'bz;
        TWP_first <= 1'b0;
	end
	else
    begin
        // RIM part
        case(state_RIM)
        IDLE: cfg_rdy <= 1'b0;
        RIM_set: cfg_rdy <= 1'b1;
        RIM_write:  Register_Spaces[cfg_addr] <= cfg_wdata;
        RIM_read: cfg_rdata <= Register_Spaces[cfg_addr];
        endcase
        // TWP part
        case(state_TWP)
        IDLE:
        begin
            TWP_addr_idx <= 3'b0;
            TWP_data_idx <= 4'b0;
            TWP_wait_count <= 1'b0;
            SDA_reg <= 1'bz;
            TWP_addr <= 8'b0;
            TWP_first <= 1'b0;
        end
        TWP_set:
        begin
            if(SDA) TWP_wr <= 1'b1; 
            else TWP_wr <= 1'b0;
            if(state_RIM == IDLE) TWP_first <= 1'b1;
        end
        TWP_gaddr:
        begin
            TWP_addr_idx <= TWP_addr_idx + 1'b1;
            TWP_addr[TWP_addr_idx] <= SDA; 
        end
        TWP_write:
        begin
            TWP_data_idx <= TWP_data_idx + 1'b1;
            TWP_read_data[TWP_data_idx] <= SDA;
        end
        TWP_write_fetch: if((TWP_addr != cfg_addr) || !TWP_first) Register_Spaces[TWP_addr] <= TWP_read_data;
        TWP_wait_read: TWP_wait_count <= TWP_wait_count + 1'b1;
        TWP_read_fetch: TWP_read_data <= Register_Spaces[TWP_addr];
        TWP_read:
        begin
            SDA_reg <= 1'b1;
            TWP_data_idx <= TWP_data_idx + 1'b1;
        end
        TWP_read_finish: SDA_reg <= 1'b1;
        endcase  
    end
end  
endmodule
