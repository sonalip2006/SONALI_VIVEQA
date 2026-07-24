`timescale 1ns / 1ps

module tb_adder_4bit();
    reg [3:0] a, b;
    reg m;
    wire [3:0] sum;
    wire carry;
    
    // Instantiate the Device Under Test (DUT)
    adder_4bit dut(a, b, m, sum, carry);
    
    initial begin
        // Test Addition (m = 0)
        m = 0;
        #10; a = 4'd1;  b = 4'd2;
        #10; a = 4'd10; b = 4'd10;
        #10; a = 4'd15; b = 4'd15;
        #10; a = 4'd0;  b = 4'd8; 
        
        // Test Subtraction (m = 1)
        #10; m = 1;
        #10; a = 4'd1;  b = 4'd2;
        #10; a = 4'd10; b = 4'd10;
        #10; a = 4'd15; b = 4'd15;
        #10; a = 4'd0;  b = 4'd8; 
        
        #10 $finish;
    end
    
    initial begin
        $monitor("Time=%0t | m=%b | a=%d | b=%d | sum=%d | carry=%b", $time, m, a, b, sum, carry);
    end
endmodule