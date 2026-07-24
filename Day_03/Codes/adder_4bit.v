`timescale 1ns / 1ps

module half_adder(
    input a, input b,
    output sum, output carry
);
    xor(sum, a, b);
    and(carry, a, b);
endmodule
 
module full_adder(
    input a, input b, input cin,
    output sum, output carry
);
    wire sum1, carry1, carry2;
    
    half_adder ha1(a, b, sum1, carry1);
    half_adder ha2(sum1, cin, sum, carry2);
    or(carry, carry1, carry2);
endmodule

module adder_4bit(
    input [3:0] a, b,
    input m,
    output [3:0] sum,
    output carry // Corrected from [3:0] carry to a 1-bit output
);
    wire c1, c2, c3;
    wire [3:0] bw;
    
    // XOR gates for 2's complement (Subtraction mode when m=1)
    xor(bw[0], b[0], m);
    xor(bw[1], b[1], m);
    xor(bw[2], b[2], m);
    xor(bw[3], b[3], m);
    
    // Ripple Carry Adder instances
    full_adder fa0(a[0], bw[0], m,  sum[0], c1);
    full_adder fa1(a[1], bw[1], c1, sum[1], c2);
    full_adder fa2(a[2], bw[2], c2, sum[2], c3);
    full_adder fa3(a[3], bw[3], c3, sum[3], carry);
endmodule