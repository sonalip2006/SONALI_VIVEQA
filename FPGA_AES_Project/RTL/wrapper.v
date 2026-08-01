// wrapper.v (ENCRYPT-ONLY VERSION -- ALL DECRYPTION REMOVED)
// Keeps AES-128/192/256 ENCRYPT only. Removes all 3 decrypt cores.
//
// Measured F7 Mux budget (from actual synthesis runs this session):
//   u_enc128: 3,109   u_enc192: 3,229   u_enc256: 8,399
//   Total: ~14,737 vs 16,300 available -- roughly 1,400-1,500 margin.
// This is a TIGHT fit. If Place/Route still fails with this version,
// the next lever is dropping u_enc256 as well (it alone is 8,399 --
// removing it would leave only ~6,338, very safe), keeping only
// AES-128/192 encrypt.
//
// mode: 2'd0 = AES-128, 2'd1 = AES-192, 2'd2 = AES-256 (encrypt only)
// op input is IGNORED in this build -- always encrypts regardless of
// what the GUI sends for op. If you want the GUI's Encrypt/Decrypt
// toggle to still make sense, just don't expose Decrypt as an option
// in the GUI when using this bitstream (or note it's a no-op).

module aes_wrapper (
  input               clk,
  input               rst,          // active-low
  input               start,
  input        [1:0]  mode,
  input               op,           // ignored -- this build only encrypts
  input        [255:0] key,
  input        [127:0] data_in,
  output       [127:0] data_out,
  output              done
);

  wire start_e128 = start & (mode == 2'd0);
  wire start_e192 = start & (mode == 2'd1);
  wire start_e256 = start & (mode == 2'd2);

  wire [127:0] ct128, ct192, ct256;
  wire         done_e128, done_e192, done_e256;

  aes_enc #(.KEY_SIZE(128)) u_enc128 (
    .clk(clk), .start(start_e128), .rst(rst),
    .pt(data_in), .key(key[127:0]),
    .ct(ct128), .done(done_e128)
  );

  aes_enc #(.KEY_SIZE(192)) u_enc192 (
    .clk(clk), .start(start_e192), .rst(rst),
    .pt(data_in), .key(key[191:0]),
    .ct(ct192), .done(done_e192)
  );

  aes_enc #(.KEY_SIZE(256)) u_enc256 (
    .clk(clk), .start(start_e256), .rst(rst),
    .pt(data_in), .key(key[255:0]),
    .ct(ct256), .done(done_e256)
  );

  // All decrypt cores (u_dec128, u_dec192, u_dec256) REMOVED to fit
  // F7 Mux budget -- see header note above.

  reg [127:0] data_out_r;
  reg         done_r;

  always @(*) begin
    case (mode)
      2'd0:    begin data_out_r = ct128; done_r = done_e128; end
      2'd1:    begin data_out_r = ct192; done_r = done_e192; end
      2'd2:    begin data_out_r = ct256; done_r = done_e256; end
      default: begin data_out_r = 128'b0; done_r = 1'b0; end
    endcase
  end

  assign data_out = data_out_r;
  assign done     = done_r;

endmodule
