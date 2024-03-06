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

localparam  IDLE=4'd0,           RIM_SET=4'd1,       RIM_READ=4'd2,         RIM_WRITE=4'd3,      
            TWP_SET=4'd4,        TWP_GETADDR=4'd5,   TWP_WAIT_READ=4'd6,    TWP_READ_SET=4'd7,     
            TWP_SEND_START=4'd8, TWP_SEND_READ=4'd9, TWP_WRITE_FETCH=4'd10, TWP_WRITE_DATA=4'd11;

reg [3:0] state_RIM, RIM_next, state_TWP, TWP_next;
reg TWP_wr, TWP_latter;
reg [2:0] TWP_addr_idx;
reg [7:0] TWP_addr;
reg [3:0] TWP_data_idx;
reg TWP_wait_read_flag, SDA_reg;
reg [15:0] TWP_read_data;

// ===== Coding your RTL below here ================================= 

// sequencial block
always@(posedge clk or negedge reset_n)
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
            if(cfg_req) RIM_next = RIM_SET;
            else RIM_next = IDLE;
        end
        RIM_SET:
        begin
            if(cfg_cmd) RIM_next = RIM_WRITE;
            else RIM_next = RIM_READ;
        end
        RIM_WRITE: RIM_next = IDLE;
        RIM_READ: RIM_next = IDLE;
        default: RIM_next = IDLE; 
	endcase
    // TWP part
    case(state_TWP)
    IDLE:
    begin
        if(!SDA) TWP_next = TWP_SET;
        else TWP_next = IDLE;
    end
    TWP_SET: TWP_next = TWP_GETADDR;
    TWP_GETADDR:
    begin
        if(TWP_addr_idx == 3'd7)
        begin
            if(TWP_wr) TWP_next = TWP_WRITE_FETCH;
            else TWP_next = TWP_WAIT_READ;
        end
        else TWP_next = TWP_GETADDR;
    end
    TWP_WAIT_READ:
    begin
        if(TWP_wait_read_flag) TWP_next = TWP_READ_SET;
        else TWP_next = TWP_WAIT_READ;
    end
    TWP_READ_SET: TWP_next = TWP_SEND_START;
    TWP_SEND_START: TWP_next = TWP_SEND_READ;
    TWP_SEND_READ:
    begin
        if(TWP_data_idx == 4'd15) TWP_next = IDLE;
        else TWP_next = TWP_SEND_READ;
    end
    TWP_WRITE_FETCH:
    begin
        if(TWP_data_idx == 4'd15) TWP_next = TWP_WRITE_DATA;
        else TWP_next = TWP_WRITE_FETCH;
    end
    TWP_WRITE_DATA: TWP_next = IDLE;
    default: TWP_next = IDLE;
    endcase
end

// take SDA as output
assign SDA=(state_TWP == TWP_SEND_READ) ? TWP_read_data[TWP_data_idx] : 
           (state_TWP == TWP_SEND_START) ? 1'b0 : SDA_reg;
// take SDA as input
wire SDA_i = SDA;

//output logic block -> RIM part
always@(posedge clk or negedge reset_n)
begin
    if(!reset_n)
    begin 
		cfg_rdy <= 1'b0;
	end
	else
    begin
        // RIM part
        case(state_RIM)
            IDLE: cfg_rdy <= 1'b0;
            RIM_SET: cfg_rdy <= 1'b1;
            RIM_WRITE:  Register_Spaces[cfg_addr] <= cfg_wdata;
            RIM_READ: cfg_rdata <= Register_Spaces[cfg_addr];
        endcase
    end
end

//output logic block -> TWS part
always@(posedge clk or negedge reset_n)
begin
    if(!reset_n)
    begin 
        TWP_addr_idx <= 3'b0;
        TWP_data_idx <= 4'b0;
        TWP_wait_read_flag <= 1'b0;
        SDA_reg <= 1'bz;
        TWP_latter <= 1'b1;
	end
	else
    begin
        // TWP part
        case(state_TWP)
            IDLE:
            begin
                TWP_addr_idx <= 3'b0;
                TWP_data_idx <= 4'b0;
                TWP_wait_read_flag <= 1'b0;
                SDA_reg <= 1'bz;
                TWP_addr <= 8'b0;
                TWP_latter <= 1'b1;
            end
            TWP_SET:
            begin
                if(SDA_i) TWP_wr <= 1'b1; 
                else TWP_wr <= 1'b0;
                // Determine RIM or TWP which one is the first
                if(!cfg_rdy) TWP_latter <= 1'b0; 
            end
            TWP_GETADDR:
            begin
                TWP_addr_idx <= TWP_addr_idx + 1'b1;
                TWP_addr[TWP_addr_idx] <= SDA_i; 
            end
            TWP_WRITE_FETCH:
            begin
                TWP_data_idx <= TWP_data_idx + 1'b1;
                TWP_read_data[TWP_data_idx] <= SDA_i;
            end
            // If TWP is not written late and its writing address is the same as RIM, avoid it.
            TWP_WRITE_DATA: if(TWP_latter || (TWP_addr != cfg_addr)) Register_Spaces[TWP_addr] <= TWP_read_data; 
            TWP_WAIT_READ: begin
                if(TWP_wait_read_flag) SDA_reg = 1'b1;
                TWP_wait_read_flag <= TWP_wait_read_flag + 1'b1;
            end
            TWP_SEND_START: TWP_read_data <= Register_Spaces[TWP_addr];
            TWP_SEND_READ:
            begin
                SDA_reg <= 1'b1;
                TWP_data_idx <= TWP_data_idx + 1'b1;
            end
        endcase  
    end
end
endmodule