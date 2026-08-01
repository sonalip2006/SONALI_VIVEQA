module shift_row (
  input [127:0] in,
  output [127:0] out 
);


wire [7:0] a00; 
wire [7:0] a10; 
wire [7:0] a20; 
wire [7:0] a30; 
wire [7:0] a01; 
wire [7:0] a11; 
wire [7:0] a21; 
wire [7:0] a31; 
wire [7:0] a02; 
wire [7:0] a12; 
wire [7:0] a22; 
wire [7:0] a32; 
wire [7:0] a03; 
wire [7:0] a13; 
wire [7:0] a23; 
wire [7:0] a33; 


assign  a00 = in[127:120];
assign  a10 = in[119:112];
assign  a20 = in[111:104];
assign  a30 = in[103:96];

assign  a01 = in[95:88];
assign  a11 = in[87:80];
assign  a21 = in[79:72];
assign  a31 = in[71:64];

assign  a02 = in[63:56];
assign  a12 = in[55:48];
assign  a22 = in[47:40];
assign  a32 = in[39:32];

assign  a03 = in[31:24];
assign  a13 = in[23:16];
assign  a23 = in[15:8];
assign  a33 = in[7:0];

assign out = {a00, a11, a22, a33, a01, a12, a23, a30, a02, a13, a20, a31, a03, a10, a21, a32};



  
endmodule