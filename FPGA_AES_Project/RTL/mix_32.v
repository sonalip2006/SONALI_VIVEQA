module mix_32 (
  input [31:0] in_col,
  output [31:0] out_col
);

wire [7:0] a0,a1,a2,a3;
wire [7:0] b0,b1,b2,b3;
wire [7:0] b [0:15];

assign a0 = in_col[31:24];
assign a1 = in_col[23:16];
assign a2 = in_col[15:8];
assign a3 = in_col[7:0];

// Using M_General Blocks
// M_General mul00 (8'd2 , a0 , b[0]);
// M_General mul01 (8'd3 , a1 , b[1]);
// M_General mul11 (8'd2 , a1 , b[5]);
// M_General mul12 (8'd3 , a2 , b[6]);
// M_General mul22 (8'd2 , a2 , b[10]);
// M_General mul23 (8'd3 , a3 , b[11]);
// M_General mul30 (8'd3 , a0 , b[12]);
// M_General mul33 (8'd2 , a3 , b[15]);


// Using M Blocks
M2 mul00(a0 , b[0]);
M2 mul11(a1 , b[5]);
M2 mul22(a2 , b[10]);
M2 mul33(a3 , b[15]);
M3 mul01(a1 , b[1]);
M3 mul12(a2 , b[6]);
M3 mul23(a3 , b[11]);
M3 mul30(a0 , b[12]);


assign b0 = b[0] ^ b[1] ^ a2 ^ a3;
assign b1 = a0 ^ b[5] ^ b[6] ^ a3;
assign b2 = a0 ^ a1 ^ b[10] ^ b[11];
assign b3 = b[12] ^ a1 ^ a2 ^ b[15];

assign out_col = {b0,b1,b2,b3};




endmodule
