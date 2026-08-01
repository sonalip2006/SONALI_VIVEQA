// wrapper_tb.v
// Standalone testbench for wrapper.v (module: aes_wrapper).
// Drives mode/op/key/data directly -- no UART involved -- to isolate
// AES core bugs from UART/controller bugs. Tests all three key sizes
// for encryption, using the same FIPS-197 vectors as the repo's own
// aes_enc_tb.v.
//
// Run this BEFORE top_tb.v. If this fails, fix it here first --
// nothing built on top of a broken wrapper is worth debugging.

`timescale 1ns/1ps

module wrapper_tb ();

  parameter CLK_PERIOD = 41.667; // 24 MHz, matches board clock

  reg          clk;
  reg          rst;      // active-low
  reg          start;
  reg  [1:0]   mode;
  reg          op;
  reg  [255:0] key;
  reg  [127:0] data_in;
  wire [127:0] data_out;
  wire         done;

  integer errors;

  aes_wrapper DUT (
    .clk      (clk),
    .rst      (rst),
    .start    (start),
    .mode     (mode),
    .op       (op),
    .key      (key),
    .data_in  (data_in),
    .data_out (data_out),
    .done     (done)
  );

  always #(CLK_PERIOD/2.0) clk = ~clk;

  // ---------------- Task: run one encrypt test and check result ----------------
  task run_test(
    input [1:0]   t_mode,
    input [255:0] t_key,
    input [127:0] t_pt,
    input [127:0] t_expected_ct,
    input [127:0] t_label   // just used as a printable tag via $display below
  );
    begin
      mode    = t_mode;
      op      = 1'b0;          // encrypt
      key     = t_key;
      data_in = t_pt;
      start   = 1'b1;
      @(posedge clk);
      start   = 1'b0;

      wait (done == 1'b1);
      @(posedge clk); // let data_out settle one more cycle since it's registered on 'done'
      #1;

      if (data_out === t_expected_ct) begin
        $display("[%0t] MODE=%0d PASS: got %h", $time, t_mode, data_out);
      end else begin
        $display("[%0t] MODE=%0d FAIL: got %h, expected %h", $time, t_mode, data_out, t_expected_ct);
        errors = errors + 1;
      end

      // let done fall back to 0 before next test
      wait (done == 1'b0);
      #(CLK_PERIOD*5);
    end
  endtask

  initial begin
    errors  = 0;
    clk     = 1'b0;
    rst     = 1'b0;
    start   = 1'b0;
    mode    = 2'd0;
    op      = 1'b0;
    key     = 256'b0;
    data_in = 128'b0;

    #(CLK_PERIOD*10);
    rst = 1'b1;
    #(CLK_PERIOD*10);

    // ---------------- AES-128 vector (from repo's aes_enc_tb.v) ----------------
    run_test(
      2'd0,
      {128'b0, 128'h00_01_02_03_04_05_06_07_08_09_0a_0b_0c_0d_0e_0f}, // key, zero-padded to 256b
      128'h00_11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff,           // plaintext
      128'h69_c4_e0_d8_6a_7b_04_30_d8_cd_b7_80_70_b4_c5_5a,           // expected ciphertext
      128'd0
    );

    // ---------------- AES-192 vector (from repo's aes_enc_tb.v) ----------------
    run_test(
      2'd1,
      {64'b0, 192'h00_01_02_03_04_05_06_07_08_09_0a_0b_0c_0d_0e_0f_10_11_12_13_14_15_16_17},
      128'h00_11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff,
      128'hdd_a9_7c_a4_86_4c_df_e0_6e_af_70_a0_ec_0d_71_91,
      128'd1
    );

    // ---------------- AES-256 vector (from repo's aes_enc_tb.v) ----------------
    run_test(
      2'd2,
      256'h00_01_02_03_04_05_06_07_08_09_0a_0b_0c_0d_0e_0f_10_11_12_13_14_15_16_17_18_19_1a_1b_1c_1d_1e_1f,
      128'h00_11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff,
      128'h8e_a2_b7_ca_51_67_45_bf_ea_fc_49_90_4b_49_60_89,
      128'd2
    );

    $display("=========================================");
    if (errors == 0)
      $display(" ALL WRAPPER TESTS PASSED (128/192/256)");
    else
      $display(" %0d TEST(S) FAILED -- see above", errors);
    $display("=========================================");

    #(CLK_PERIOD*10);
    $stop;
  end

endmodule
