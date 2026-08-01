// aes_enc.v (ITERATIVE VERSION -- replaces the fully-unrolled original)
//
// WHY THIS EXISTS: the original aes_enc.v built separate physical hardware
// for every single round (10/12/14 copies of SubBytes+ShiftRows+MixColumns+
// AddRoundKey, "unrolled" via a generate loop). That used far more LUTs
// than the XC7A35T has available once 3 key sizes were instantiated
// together (33,565 LUTs needed vs 20,800 available).
//
// This version builds ONE round's worth of hardware and reuses it every
// clock cycle via a small FSM and a round counter -- the classic
// "iterative" AES architecture. Same algorithm, same key_gen.v (unchanged,
// key schedule is still computed once combinationally), same round-key
// bit ordering convention as the original (see the cur_round_key
// assignment below). Takes ROUNDS+2 clock cycles to complete instead of
// 1, which is irrelevant here since this only needs to keep up with a
// 115200 baud UART, not a high-throughput application.
//
// PORT INTERFACE IS IDENTICAL to the original aes_enc.v -- this is a
// drop-in replacement. No changes needed in wrapper.v, controller.v, or
// top.v.

module aes_enc #(parameter KEY_SIZE = 128) (
  input                       clk,
  input                       start,
  input                       rst,          // active-low, async
  input       [127:0]         pt,
  input       [KEY_SIZE-1:0]  key,
  output reg  [127:0]         ct,
  output reg                  done
);

  localparam ROUNDS = (KEY_SIZE == 128) ? 10 : (KEY_SIZE == 192) ? 12 : 14;

  // Key schedule: computed once, combinationally, exactly as before.
  // This is NOT what caused the resource problem -- it's the round
  // datapath (SubBytes/ShiftRows/MixColumns/AddRoundKey) being repeated
  // ROUNDS times that did. key_gen.v itself is unchanged.
  wire [(ROUNDS+1)*128-1:0] w;
  key_gen #(.KEY_SIZE(KEY_SIZE), .ROUNDS(ROUNDS)) k (.key(key), .w(w));

  // Round-key extraction, matching the ORIGINAL aes_enc.v's convention
  // exactly: round_cnt=0 (initial AddRoundKey) uses the topmost block
  // (block index ROUNDS); round_cnt=ROUNDS (final round) uses block 0.
  // This is a variable-indexed READ from a wide WIRE (not a register),
  // which synthesizes as an ordinary input mux -- cheap, not the
  // expensive pattern that caused problems elsewhere in this project
  // (that was always about variable-indexed WRITES into a register).
  reg [3:0] round_cnt;  // 0..14, fits comfortably in 4 bits
  wire [127:0] cur_round_key = w[(ROUNDS - round_cnt + 1)*128 - 1 -: 128];

  reg [127:0] state;
  localparam S_IDLE  = 2'd0;
  localparam S_INIT  = 2'd1;
  localparam S_ROUND = 2'd2;
  localparam S_DONE  = 2'd3;
  reg [1:0] fsm_state;

  // One round's worth of combinational datapath, reused every cycle.
  wire [127:0] post_subs, post_shift, post_mix;
  wire is_last_round = (round_cnt == ROUNDS[3:0]);

  subs_bytes sub  (.in(state),     .out(post_subs));
  shift_row  shift(.in(post_subs), .out(post_shift));
  mix_128    mix  (.in(post_shift),.out(post_mix));

  wire [127:0] pre_addrk = is_last_round ? post_shift : post_mix;
  wire [127:0] round_result;
  add_rk #(.WIDTH(128)) add (.in1(pre_addrk), .in2(cur_round_key), .out(round_result));

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      fsm_state <= S_IDLE;
      round_cnt <= 4'd0;
      state     <= 128'b0;
      ct        <= 128'b0;
      done      <= 1'b0;
    end else begin
      case (fsm_state)

        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            state     <= pt;      // load plaintext; XORed with key(0) next cycle
            round_cnt <= 4'd0;
            fsm_state <= S_INIT;
          end
        end

        S_INIT: begin
          // Initial AddRoundKey: state = pt XOR round_key(0). cur_round_key
          // at round_cnt=0 correctly evaluates to the topmost block (the
          // original key words), matching the original module's behavior.
          state     <= state ^ cur_round_key;
          round_cnt <= 4'd1;
          fsm_state <= S_ROUND;
        end

        S_ROUND: begin
          // Apply one full round (SubBytes+ShiftRows+MixColumns unless
          // last+AddRoundKey) using the CURRENT round_cnt's key.
          state <= round_result;
          if (round_cnt == ROUNDS[3:0]) begin
            fsm_state <= S_DONE;
          end else begin
            round_cnt <= round_cnt + 4'd1;
          end
        end

        S_DONE: begin
          ct        <= state;
          done      <= 1'b1;
          fsm_state <= S_IDLE;
        end

        default: fsm_state <= S_IDLE;
      endcase
    end
  end

endmodule
