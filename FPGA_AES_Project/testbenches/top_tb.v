// top_tb.v
// Full-chain simulation testbench: drives uart_rx's rx_serial pin exactly
// like a real PC UART would, watches uart_tx's tx_serial pin for the
// response, and checks it against the known FIPS-197 AES-128 vector used
// in the repo's own aes_enc_tb.v:
//
//   Key:        00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f
//   Plaintext:  00 11 22 33 44 55 66 77 88 99 aa bb cc dd ee ff
//   Ciphertext: 69 c4 e0 d8 6a 7b 04 30 d8 cd b7 80 70 b4 c5 5a
//
// Run this against top.v (instantiate DUT = top). Baud timing matches
// uart_rx.v / uart_tx.v defaults: CLKS_PER_BIT = 208 @ 24 MHz.

`timescale 1ns/1ps

module top_tb ();

  parameter CLK_PERIOD    = 41.667;  // 24 MHz
  parameter CLKS_PER_BIT  = 208;
  parameter BIT_PERIOD_NS = CLK_PERIOD * CLKS_PER_BIT; // ~8680.6 ns per UART bit

  reg clk;
  reg rst_n;
  reg uart_rx_pin;      // drives DUT's rx_serial input (idle = 1)
  wire uart_tx_pin;      // DUT's tx_serial output
  wire [7:0] led;

  // ---------------- DUT ----------------
  top DUT (
    .clk_24mhz   (clk),
    .rst_n       (rst_n),
    .uart_rx_pin (uart_rx_pin),
    .uart_tx_pin (uart_tx_pin),
    .led         (led)
  );

  // ---------------- Clock ----------------
  initial clk = 1'b0;
  always #(CLK_PERIOD/2.0) clk = ~clk;

  // ---------------- Expected result ----------------
  // ciphertext bytes, index 0 = LSB byte (matches controller.v packing:
  // byte0 -> data_out[7:0], byte1 -> data_out[15:8], etc.)
  reg [7:0] expected_ct [0:15];

  // ---------------- Task: send one UART byte on uart_rx_pin ----------------
  task send_byte(input [7:0] b);
    integer i;
    begin
      uart_rx_pin = 1'b0;                 // start bit
      #(BIT_PERIOD_NS);
      for (i = 0; i < 8; i = i + 1) begin
        uart_rx_pin = b[i];
        #(BIT_PERIOD_NS);
      end
      uart_rx_pin = 1'b1;                 // stop bit
      #(BIT_PERIOD_NS);
    end
  endtask

  // ---------------- Task: receive one UART byte from uart_tx_pin ----------------
  task recv_byte(output [7:0] b);
    integer i;
    begin
      // wait for start bit (falling edge)
      wait (uart_tx_pin == 1'b0);
      #(BIT_PERIOD_NS * 1.5);             // move to middle of first data bit
      for (i = 0; i < 8; i = i + 1) begin
        b[i] = uart_tx_pin;
        #(BIT_PERIOD_NS);
      end
      // now at stop bit, no need to sample it
    end
  endtask

  integer j;
  reg [7:0] rx_result [0:15];
  reg [7:0] start_byte, end_byte;
  reg pass;

  initial begin
    // ---------------- Init ----------------
    rst_n       = 1'b0;
    uart_rx_pin = 1'b1;   // idle HIGH
    pass        = 1'b1;

    expected_ct[0]  = 8'h69;  expected_ct[1]  = 8'hc4;  expected_ct[2]  = 8'he0;  expected_ct[3]  = 8'hd8;
    expected_ct[4]  = 8'h6a;  expected_ct[5]  = 8'h7b;  expected_ct[6]  = 8'h04;  expected_ct[7]  = 8'h30;
    expected_ct[8]  = 8'hd8;  expected_ct[9]  = 8'hcd;  expected_ct[10] = 8'hb7;  expected_ct[11] = 8'h80;
    expected_ct[12] = 8'h70;  expected_ct[13] = 8'hb4;  expected_ct[14] = 8'hc5;  expected_ct[15] = 8'h5a;

    #(CLK_PERIOD*10);
    rst_n = 1'b1;
    #(CLK_PERIOD*10);

    // ---------------- Send request packet ----------------
    // [0xAA][MODE=0x00][OP=0x00][KEY 16B][DATA 16B][0x55]
    send_byte(8'hAA);   // start
    send_byte(8'h00);   // mode = AES-128
    send_byte(8'h00);   // op = encrypt

    // key bytes: 00 01 02 ... 0f  (byte0 -> aes_key[7:0], i.e. sent in this order)
    for (j = 0; j < 16; j = j + 1)
      send_byte(j[7:0]);

    // plaintext bytes: 00 11 22 33 44 55 66 77 88 99 aa bb cc dd ee ff
    send_byte(8'h00); send_byte(8'h11); send_byte(8'h22); send_byte(8'h33);
    send_byte(8'h44); send_byte(8'h55); send_byte(8'h66); send_byte(8'h77);
    send_byte(8'h88); send_byte(8'h99); send_byte(8'haa); send_byte(8'hbb);
    send_byte(8'hcc); send_byte(8'hdd); send_byte(8'hee); send_byte(8'hff);

    send_byte(8'h55);   // end byte

    $display("[%0t] Request packet sent, waiting for response...", $time);

    // ---------------- Receive response ----------------
    recv_byte(start_byte);
    if (start_byte !== 8'hAA) begin
      $display("FAIL: response start byte was %h, expected AA", start_byte);
      pass = 1'b0;
    end

    for (j = 0; j < 16; j = j + 1)
      recv_byte(rx_result[j]);

    recv_byte(end_byte);
    if (end_byte !== 8'h55) begin
      $display("FAIL: response end byte was %h, expected 55", end_byte);
      pass = 1'b0;
    end

    // ---------------- Compare ----------------
    for (j = 0; j < 16; j = j + 1) begin
      if (rx_result[j] !== expected_ct[j]) begin
        $display("FAIL: byte %0d = %h, expected %h", j, rx_result[j], expected_ct[j]);
        pass = 1'b0;
      end
    end

    if (pass) begin
      $display("=========================================");
      $display(" TEST PASSED: AES-128 result matches FIPS-197 vector end-to-end");
      $display("=========================================");
    end else begin
      $display("=========================================");
      $display(" TEST FAILED -- see mismatches above");
      $display("=========================================");
    end

    #(CLK_PERIOD*20);
    $stop;
  end

endmodule
