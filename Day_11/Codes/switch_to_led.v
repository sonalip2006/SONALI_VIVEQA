`timescale 1ns / 1ps

module switch_to_led(
  
    input  [7:0] switch,
    output [7:0] led
);

assign led = switch;

endmodule