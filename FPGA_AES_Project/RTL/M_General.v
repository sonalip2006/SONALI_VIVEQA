module M_General (
  input [7:0] op1,
  input [7:0] op2,
  output reg [7:0] result
);

function [7:0] M2;
    input [7:0] x;
    M2 = (x[7])?(x<<1 ^ 'h1b):(x<<1);
endfunction

function [7:0] M3;
    input [7:0] x;
    M3 = M2(x) ^ x;
endfunction

function [7:0] M9;
    input [7:0] x;
    M9 = M2(M2(M2(x))) ^ x;
endfunction

function [7:0] M11;
    input [7:0] x;
    M11 = M2(M2(M2(x))^ x) ^ x;
endfunction

function [7:0] M13;
    input [7:0] x;
    M13 = M2(M2(M2(x)^ x)) ^ x;
endfunction

function [7:0] M14;
    input [7:0] x;
    M14 = M2(M2(M2(x)^ x) ^ x);
endfunction


always @(*) begin
  case (op1) 
    8'd2  : result = M2(op2);
    8'd3  : result = M3(op2);
    8'd9  : result = M9(op2);
    8'd11 : result = M11(op2);
    8'd13 : result = M13(op2);
    8'd14 : result = M14(op2);
    default: result = 8'h00;
  endcase
end

  
endmodule
