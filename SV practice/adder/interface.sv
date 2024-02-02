interface MMS_if(input bit clk);
logic sel;
logic  [7:0] num0;
logic  [7:0] num1;
logic  [7:0] res;

modport TEST(output sel,num0,num1,
            input res,clk);
// modport DUT(output res,
//             input sel,num0,num1,clk);

endinterface