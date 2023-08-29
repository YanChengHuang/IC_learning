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

parameter [3:0] SET_FETCH=4'd0, 
				FETCH_FAKE=4'd1,
				FETCH_KERNEL_IDX=4'd2, 
				CAL=4'd3,
				STORE_0=4'd4,
				SET_FETCH_0=4'd5,
				FETCH_0=4'd6,
				FIND_MAX=4'd7,
				STORE_1=4'd8,
				FINISH=4'd9,
				IDLE=4'd10;

reg [1:0] max_kernel;
reg [3:0] state_reg, state_next;
reg [11:0] layer_0_idx;
reg [3:0] kernel_count;
reg signed [12:0] conv_val, max_value;
reg [9:0] layer_1_idx;

// sequencial block
always@(posedge clk)
begin
	if(reset)begin
		state_reg <= SET_FETCH;
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
        SET_FETCH: //0
		begin
			if(ready)	state_next = FETCH_FAKE;
			else state_next = SET_FETCH ;
		end
		FETCH_FAKE: //1
        begin            
			state_next = FETCH_KERNEL_IDX;
        end
		FETCH_KERNEL_IDX: //2
		begin
			state_next = CAL;
		end
		CAL: //3
		begin
			if(kernel_count == 4'd8) state_next = STORE_0;
			else state_next = FETCH_KERNEL_IDX;
		end
		STORE_0: //4
		begin
			if(layer_0_idx == 4095) state_next = SET_FETCH_0;
			else state_next = FETCH_KERNEL_IDX;
		end
		SET_FETCH_0://5
		begin
			state_next = FETCH_0;
		end
		FETCH_0://6
		begin
			state_next = FIND_MAX;
		end
		FIND_MAX://7
		begin
			if(max_kernel == 2'd3) state_next = STORE_1;
			else state_next = FETCH_0;
		end
		STORE_1://8
		begin
			if(layer_1_idx == 1023) state_next = FINISH;
			else state_next = FETCH_0;
		end
		default: state_next = FETCH_FAKE;
    endcase
end

wire [12:0] conv_op = conv_val + 13'h1ff4;
wire [5:0] layer_0_idx_final_5_bits = layer_0_idx[5:0];
//output logic block
always@(posedge clk or posedge reset)
begin
	if(reset)
    begin
		busy <= 1'b0;
		iaddr <= 12'b0;
		csel <= 1'b0; // select which layer memory will be written
		crd <= 1'b0; // read enabel signal
		caddr_rd <= 12'b0; // read address signal
		cwr <= 1'b0; // write enable signal
		caddr_wr <= 12'b0; // write address signal
		conv_val <= 13'b0;
	end
	else
	begin
		case(state_reg)
		SET_FETCH:
		begin
			busy <= 1'b0;
			layer_0_idx <= 12'b111111111111;
			kernel_count <= 4'd0;
			layer_1_idx <= 10'd0;
			max_kernel <= 2'b0;
			max_value <= 13'b0;
		end
		FETCH_FAKE:
		begin
			busy <= 1'b1;
			cwr <= 0;
			layer_0_idx <= layer_0_idx + 1'b1;	
		end
		FETCH_KERNEL_IDX:
		begin
			case(kernel_count)
				3'd0: 
				begin
					if(layer_0_idx < 64)
					begin
						case(layer_0_idx_final_5_bits)
							0: iaddr <= layer_0_idx;
							1:  iaddr <= layer_0_idx-12'd1;
							default: iaddr <= layer_0_idx-12'd2;
						endcase
					end
					else if(layer_0_idx < 128)
					begin
						case(layer_0_idx_final_5_bits)
							0: iaddr <= layer_0_idx-12'd64;
							1:  iaddr <= layer_0_idx-12'd1-12'd64;
							default: iaddr <= layer_0_idx-12'd2-12'd64;
						endcase
					end
					else
					begin
						case(layer_0_idx_final_5_bits)
							0: iaddr <= layer_0_idx-12'd128;
							1:  iaddr <= layer_0_idx-12'd1-12'd128;
							default: iaddr <= layer_0_idx-12'd2-12'd128;
						endcase
					end
				end
				3'd1: 
				begin
					if(layer_0_idx < 12'd64) iaddr <= layer_0_idx;
					else if(layer_0_idx < 12'd128) iaddr <= layer_0_idx-12'd64;
					else iaddr <= layer_0_idx-12'd128;
				end
				3'd2: 
				begin
					if(layer_0_idx < 12'd64)
					begin
						case(layer_0_idx_final_5_bits)
							62: iaddr <= layer_0_idx+12'd1;
							63:  iaddr <= layer_0_idx;
							default: iaddr <= layer_0_idx+12'd2;
						endcase
					end
					else if(layer_0_idx < 12'd128)
					begin
						case(layer_0_idx_final_5_bits)
							62: iaddr <= layer_0_idx-12'd64+12'd1;
							63:  iaddr <= layer_0_idx-12'd64;
							default: iaddr <= layer_0_idx+12'd2-12'd64;
						endcase
					end
					else
					begin
						case(layer_0_idx_final_5_bits)
							62: iaddr <= layer_0_idx-12'd128+12'd1;
							63:  iaddr <= layer_0_idx-12'd128;
							default: iaddr <= layer_0_idx-12'd128+12'd2;
						endcase
					end
				end
				3'd3: 
				begin
					case(layer_0_idx_final_5_bits)
						0: iaddr <= layer_0_idx;
						1:  iaddr <= layer_0_idx-12'd1;
						default: iaddr <= layer_0_idx-12'd2;
					endcase
				end
				3'd4: 	iaddr <= layer_0_idx;
				3'd5: 
				begin
					case(layer_0_idx_final_5_bits)
						62: iaddr <= layer_0_idx+12'd1;
						63: iaddr <= layer_0_idx;
						default: iaddr <= layer_0_idx+12'd2;
					endcase
				end
				3'd6: 
				begin
					if(layer_0_idx > 4031)
					begin
						case(layer_0_idx_final_5_bits)
							0: iaddr <= layer_0_idx;
							1:  iaddr <= layer_0_idx-12'd1;
							default: iaddr <= layer_0_idx-12'd2;
						endcase
					end
					else if(layer_0_idx >3967)
					begin
						case(layer_0_idx_final_5_bits)
							0: iaddr <= layer_0_idx+12'd64;
							1:  iaddr <= layer_0_idx-12'd1+12'd64;
							default: iaddr <= layer_0_idx-12'd2+12'd64;
						endcase
					end
					else
					begin
						case(layer_0_idx_final_5_bits)
							0: iaddr <= layer_0_idx+12'd128;
							1:  iaddr <= layer_0_idx-12'd1+12'd128;
							default: iaddr <= layer_0_idx-12'd2+12'd128;
						endcase
					end
				end
				3'd7:
				begin
					if(layer_0_idx > 12'd4031) iaddr <= layer_0_idx;
					else if(layer_0_idx > 12'd3967) iaddr <= layer_0_idx+12'd64;
					else iaddr <= layer_0_idx+12'd128;
				end 
				default: 
				begin
					if(layer_0_idx > 12'd4031)
					begin
						case(layer_0_idx_final_5_bits)
							62: iaddr <= layer_0_idx+12'd1;
							63:  iaddr <= layer_0_idx;
							default: iaddr <= layer_0_idx+12'd2;
						endcase
					end
					else if(layer_0_idx > 12'd3967)
					begin
						case(layer_0_idx_final_5_bits)
							62: iaddr <= layer_0_idx+12'd64+12'd1;
							63:  iaddr <= layer_0_idx+12'd64;
							default: iaddr <= layer_0_idx+12'd2+12'd64;
						endcase
					end
					else
					begin
						case(layer_0_idx_final_5_bits)
							62: iaddr <= layer_0_idx+12'd128+12'd1;
							63:  iaddr <= layer_0_idx+12'd128;
							default: iaddr <= layer_0_idx+12'd128+12'd2;
						endcase
					end
				end
			endcase
		end
		CAL:
		begin
			case(kernel_count)
			3'd0: conv_val <= conv_val + (~(idata >> 4)+1'b1);
			3'd1: conv_val <= conv_val + (~(idata >> 3)+1'b1);
			3'd2: conv_val <= conv_val + (~(idata >> 4)+1'b1);
			3'd3: conv_val <= conv_val + (~(idata >> 2)+1'b1);
			3'd4: conv_val <= conv_val + idata;
			3'd5: conv_val <= conv_val + (~(idata >> 2)+1'b1);
			3'd6: conv_val <= conv_val + (~(idata >> 4)+1'b1);
			3'd7: conv_val <= conv_val + (~(idata >> 3)+1'b1);
			default: conv_val <= conv_val + (~(idata >> 4)+1'b1);
			endcase
			if(kernel_count == 4'd8) kernel_count <= 4'b0;
			else kernel_count <= kernel_count + 1'b1;
		end
		STORE_0:
		begin
			if(conv_op[12]) cdata_wr <= 13'b0;
		  	else cdata_wr <= conv_op;
			cwr <= 1'b1;
			caddr_wr <= layer_0_idx;
			conv_val <= 13'b0;
			if(layer_0_idx!=12'd4095) layer_0_idx <= layer_0_idx + 1'b1;
		end
		SET_FETCH_0:
		begin
			cwr <= 1'b0;
			crd <= 1'b1;
			layer_0_idx <= layer_0_idx + 1'b1;
		end
		FETCH_0:
		begin
			csel <= 1'b0;
			cwr <= 1'b0;
			crd <= 1'b1;
			caddr_rd <= layer_0_idx;
		end
		FIND_MAX:
		begin
			if(cdata_rd > max_value) 
			begin
				if(cdata_rd[3:0] != 0) 	max_value <= cdata_rd - cdata_rd[3:0] + 5'd16;
				else max_value <= cdata_rd;
			end
			case(max_kernel)
				2'd0: layer_0_idx <= layer_0_idx + 12'd1;
				2'd1: layer_0_idx <= layer_0_idx + 12'd63;
				2'd2: layer_0_idx <= layer_0_idx + 12'd1;
				default: 
				begin
					if(layer_0_idx_final_5_bits == 12'd63) layer_0_idx <= layer_0_idx + 1'b1;
					else layer_0_idx <= layer_0_idx - 12'd63;
					
				end
			endcase
			max_kernel <= max_kernel + 1'b1;
		end
		STORE_1:
		begin
			csel <= 1'b1;
			cwr <= 1'b1;
			crd <= 1'b0;
			cdata_wr <= max_value;
			caddr_wr <= layer_1_idx;
			layer_1_idx <= layer_1_idx + 1'b1;
			max_value <= 13'b0;
		end
		FINISH:
		begin
			busy <= 1'b0;
		end
		endcase
	end
end
endmodule