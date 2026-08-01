module g #(parameter ROUND = 1) (
  input   [31:0]  win,
  output  [31:0]  wout
);

localparam  RC = 80'h01_02_04_08_10_20_40_80_1B_36; // Round Constants 10, 8, 7


wire [7:0] b0, b1, b2, b3;
wire [7:0] b0_s, b1_s, b2_s, b3_s;
wire [7:0] rc; 

assign b0 = win[31:24];
assign b1 = win[23:16];
assign b2 = win[15:8];
assign b3 = win[7:0];

sbox s0 (.in(b0), .out(b0_s));
sbox s1 (.in(b1), .out(b1_s));
sbox s2 (.in(b2), .out(b2_s));
sbox s3 (.in(b3), .out(b3_s));

assign rc = RC[79 - 8*(ROUND-1) : 72 - 8*(ROUND-1)];
assign wout = {(b1_s ^ rc), b2_s, b3_s, b0_s};
  
endmodule