module add_rk #(parameter WIDTH = 1) (
  input   [WIDTH-1:0] in1,
  input   [WIDTH-1:0] in2,
  output  [WIDTH-1:0] out
);

assign out = in1 ^ in2;

  
endmodule
