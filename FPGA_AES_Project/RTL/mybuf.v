module mybuf #(parameter WIDTH = 1) (
  output  [WIDTH-1:0] out,
  input   [WIDTH-1:0] in
);
  assign out = in;
endmodule
