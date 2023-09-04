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
output		cfg_rdy;
input		cfg_cmd;
input	[7:0]	cfg_addr;
input	[15:0]	cfg_wdata;
output	[15:0]  cfg_rdata;

reg	[15:0] Register_Spaces	[0:255];

// ===== Coding your RTL below here ================================= 







endmodule
