// aes_enc_iter_tb.v
// Quick standalone testbench for the NEW iterative aes_enc.v.
// Tests all three key sizes against the same FIPS-197 vectors used
// throughout this project. Run this BEFORE synthesizing -- it takes
// seconds, not 20-30 minutes, and will catch any FSM/timing bug in the
// iterative rewrite immediately.

`timescale 1ns/1ps

module aes_enc_iter_tb ();

  parameter CLK_PERIOD = 10;

  reg clk, rst, start;
  reg [127:0] pt;
  reg [255:0] key256;
  wire [127:0] ct;
  wire done;

  reg [1:0] test_mode; // 0=128,1=192,2=256
  integer errors;

  // Instantiate all 3 sizes; only the selected one is driven with start
  wire start128 = start & (test_mode == 2'd0);
  wire start192 = start & (test_mode == 2'd1);
  wire start256 = start & (test_mode == 2'd2);

  wire [127:0] ct128, ct192, ct256;
  wire done128, done192, done256;

  aes_enc #(.KEY_SIZE(128)) u128 (.clk(clk), .start(start128), .rst(rst), .pt(pt), .key(key256[127:0]),  .ct(ct128), .done(done128));
  aes_enc #(.KEY_SIZE(192)) u192 (.clk(clk), .start(start192), .rst(rst), .pt(pt), .key(key256[191:0]),  .ct(ct192), .done(done192));
  aes_enc #(.KEY_SIZE(256)) u256 (.clk(clk), .start(start256), .rst(rst), .pt(pt), .key(key256[255:0]),  .ct(ct256), .done(done256));

  always #(CLK_PERIOD/2) clk = ~clk;

  task run_test(input [1:0] mode, input [255:0] tkey, input [127:0] tpt, input [127:0] expected, input integer max_cycles);
    integer cyc;
    reg [127:0] got;
    reg got_done;
    begin
      test_mode = mode;
      key256 = tkey;
      pt = tpt;
      start = 1'b1;
      @(posedge clk);
      start = 1'b0;

      got_done = 1'b0;
      for (cyc = 0; cyc < max_cycles && !got_done; cyc = cyc + 1) begin
        @(posedge clk);
        case (mode)
          2'd0: if (done128) begin got = ct128; got_done = 1'b1; end
          2'd1: if (done192) begin got = ct192; got_done = 1'b1; end
          2'd2: if (done256) begin got = ct256; got_done = 1'b1; end
        endcase
      end

      if (!got_done) begin
        $display("MODE=%0d FAIL: never asserted done within %0d cycles", mode, max_cycles);
        errors = errors + 1;
      end else if (got !== expected) begin
        $display("MODE=%0d FAIL: got %h, expected %h (took %0d cycles)", mode, got, expected, cyc);
        errors = errors + 1;
      end else begin
        $display("MODE=%0d PASS: got %h correctly (took %0d cycles)", mode, got, cyc);
      end

      @(posedge clk); @(posedge clk); // small gap before next test
    end
  endtask

  initial begin
    errors = 0;
    clk = 0; rst = 0; start = 0; test_mode = 0; pt = 0; key256 = 0;
    #(CLK_PERIOD*5);
    rst = 1;
    #(CLK_PERIOD*5);

    // AES-128
    run_test(2'd0,
      {128'b0, 128'h00_01_02_03_04_05_06_07_08_09_0a_0b_0c_0d_0e_0f},
      128'h00_11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff,
      128'h69_c4_e0_d8_6a_7b_04_30_d8_cd_b7_80_70_b4_c5_5a,
      50);

    // AES-192
    run_test(2'd1,
      {64'b0, 192'h00_01_02_03_04_05_06_07_08_09_0a_0b_0c_0d_0e_0f_10_11_12_13_14_15_16_17},
      128'h00_11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff,
      128'hdd_a9_7c_a4_86_4c_df_e0_6e_af_70_a0_ec_0d_71_91,
      50);

    // AES-256
    run_test(2'd2,
      256'h00_01_02_03_04_05_06_07_08_09_0a_0b_0c_0d_0e_0f_10_11_12_13_14_15_16_17_18_19_1a_1b_1c_1d_1e_1f,
      128'h00_11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff,
      128'h8e_a2_b7_ca_51_67_45_bf_ea_fc_49_90_4b_49_60_89,
      50);

    $display("=========================================");
    if (errors == 0)
      $display(" ALL ITERATIVE AES-ENC TESTS PASSED (128/192/256)");
    else
      $display(" %0d TEST(S) FAILED -- see above", errors);
    $display("=========================================");

    #(CLK_PERIOD*10);
    $stop;
  end

endmodule
