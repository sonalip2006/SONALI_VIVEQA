`timescale 1ns / 1ps

module full_adder_tb();
    reg a, b, cin;
    wire sum, carry;

    // Instantiate the Device Under Test (DUT)
    full_adder dut(a, b, cin, sum, carry);

    integer i;

    initial begin
        // Apply inputs using a loop
        for(i = 0; i < 8; i = i + 1) begin
            {a, b, cin} = i;
            #10;
        end
        $finish;
    end
endmodule