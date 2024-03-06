`timescale 1ns/10ps
module  ATCONV(
	input		clk,
	input		reset,
	output	reg	busy,	
	input		ready,	
			
	output reg	[11:0]	iaddr,
	input signed [12:0]	idata,
	
	output	reg 	cwr,
	output  reg	[11:0]	caddr_wr,
	output reg 	[12:0] 	cdata_wr,
	
	output	reg 	crd,
	output reg	[11:0] 	caddr_rd,
	input 	[12:0] 	cdata_rd,
	
	output reg 	csel
	);
// state declaration
localparam INIT = 0; 
localparam ATCONV_PADDING = 1;
localparam LAYER0_WRITERELU = 2;
localparam MAXPOOING = 3;
localparam LAYER1_WRITECEILING = 4;
localparam FINISH = 5;

//kernel & bias
wire signed [12:0] kernel [1:9];
assign kernel[1] = 13'h1FFF; assign kernel[2] = 13'h1FFE; assign kernel[3] = 13'h1FFF;
assign kernel[4] = 13'h1FFC; assign kernel[5] = 13'h0010; assign kernel[6] = 13'h1FFC;
assign kernel[7] = 13'h1FFF; assign kernel[8] = 13'h1FFE; assign kernel[9] = 13'h1FFF;
wire signed [12:0] bias;
assign bias = 13'h1FF4;

//regs
reg [2:0] state, state_next;
reg [11:0] center; // {center[11:6]=row, center[5:0]=col}
reg [3:0] counter;
reg signed [25:0] conv_res; // {conv_res[25:8]=integer, conv_res[7:0]=fraction}

//constant 
localparam LENGTH = 6'd63; //6'd111111
localparam ZERO = 6'd0;

//wire constants
wire [5:0] cx_add2, cx_minus2, cy_add2, cy_minus2;
assign cy_add2 = center[11:6] + 6'd2;
assign cy_minus2 = center[11:6] - 6'd2;
assign cx_add2 = center[5:0] + 6'd2;
assign cx_minus2 = center[5:0] - 6'd2;

//state control (sequential)
always @(posedge clk or posedge reset) begin
    if(reset) state <= INIT;
    else state <= state_next;
end

//next state logic
always @(*) begin
    case(state) 
    INIT: begin
        if(ready) state_next = ATCONV_PADDING;
        else state_next = INIT;
    end
    ATCONV_PADDING: begin
        if(counter == 4'd9) state_next = LAYER0_WRITERELU; //0-9 totally 10 cycles, 1 cycle for waiting
        else state_next = ATCONV_PADDING;
    end
    LAYER0_WRITERELU: begin
        if(center == 12'd4095) state_next = MAXPOOING;
        else state_next = ATCONV_PADDING;
    end
    MAXPOOING: begin
        if(counter == 4'd4) state_next = LAYER1_WRITECEILING;  
        else state_next = MAXPOOING;
    end
    LAYER1_WRITECEILING: begin
        if(caddr_wr == 12'd1023) state_next = FINISH;
        else state_next = MAXPOOING;
    end
    default: state_next = INIT;
    endcase
end

// main sequential block
always @(posedge clk or posedge reset) begin
    if(reset) begin
        busy <= 1'b0;
        iaddr <= 12'd0;
        cwr <= 1'd0;
        caddr_wr <= 12'd0;
        cdata_wr <= 13'd0;
        crd <= 1'd1;
        caddr_rd <= 12'd0;
        csel <= 1'd0;

        center <= {6'd0, 6'd0};
        counter <= 4'd0;
        conv_res <= {{9{1'b1}}, bias, 4'd0}; //write bias directly at reset, because it is signed reg write 9th 1 at first 
    end
    else begin
        case(state)
            INIT: if(ready) busy <= 1'd1;
            ATCONV_PADDING: begin
                csel <= 1'd0;
                crd <= 1'd0;
                cwr <= 1'd0;

                if(counter > 4'd0) conv_res <= conv_res + idata*kernel[counter];
                counter <= counter + 4'd1;

                // handle padding part
                case(counter) // y axis part
                    0,1,2: iaddr[11:6] <= ((center[11:6]==6'd0) || (center[11:6]==6'd1))? ZERO: cy_minus2;
                    3,4,5: iaddr[11:6] <= center[11:6];
                    6,7,8: iaddr[11:6] <= ((center[11:6]==LENGTH - 6'd1) || (center[11:6]==LENGTH))? LENGTH: cy_add2;
                endcase

                case(counter) // x axis part
                    0,3,6: iaddr[5:0] <= ((center[5:0]==6'd0) || (center[5:0]==6'd1))? ZERO: cx_minus2;
                    1,4,7: iaddr[5:0] <= center[5:0];
                    2,5,8: iaddr[5:0] <= ((center[5:0]==LENGTH-6'd1) || (center[5:0]==LENGTH))? LENGTH: cx_add2;
                endcase
            end
            LAYER0_WRITERELU: begin
                csel <= 1'd0;
                crd <= 1'd0;
                cwr <= 1'd1;
                caddr_wr <= center;
                cdata_wr <= (conv_res[25])? 13'd0: conv_res[16:4]; //ReLU
                
                conv_res <= {{9{1'b1}}, bias, 4'd0};
                center <= center + 12'd1;
                counter <= 4'd0;
            end
            MAXPOOING: begin
                csel <= 1'd0;
                crd <= 1'd1;
                cwr <= 1'd0;

                if(counter == 0) cdata_wr <= 13'd0;
                else if(cdata_rd > cdata_wr) cdata_wr <= cdata_rd;
                counter <= counter + 4'd1;

                case(counter) // for y axis
                    0,1: caddr_rd[11:6] <= {center[9:5], 1'd0};
                    2,3: caddr_rd[11:6] <= {center[9:5], 1'd1};
                endcase

                case(counter) // for y axis
                    0,2: caddr_rd[5:0] <= {center[4:0], 1'd0};
                    1,3: caddr_rd[5:0] <= {center[4:0], 1'd1};
                endcase
            end
            LAYER1_WRITECEILING: begin
                csel <= 1'd1;
                crd <= 1'd0;
                cwr <= 1'd1;
                caddr_wr <= center;
                cdata_wr <= { cdata_wr[12:4] + {8'd0,|cdata_wr[3:0]}, 4'd0}; //round up

                center <= center + 12'd1;
                counter <= 4'd0;
            end
            FINISH: busy <= 1'd0;
        endcase
    end
end

endmodule