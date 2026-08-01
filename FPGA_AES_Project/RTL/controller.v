// controller.v
// Parses the UART packet protocol, drives aes_wrapper, and sends the
// result back over UART.
//
// PACKET PROTOCOL (must match your Python GUI exactly):
//   Byte 0        : START byte  = 0xAA
//   Byte 1        : MODE        = 0x00 (AES-128) / 0x01 (AES-192) / 0x02 (AES-256)
//   Byte 2        : OP          = 0x00 (encrypt) / 0x01 (decrypt)
//   Byte 3..N     : KEY         = 16 / 24 / 32 bytes depending on MODE
//   Byte N+1..N+16: DATA        = 16 bytes (plaintext if OP=0, ciphertext if OP=1)
//   Byte N+17     : END byte    = 0x55
//
// RESPONSE (sent back to PC after processing):
//   Byte 0        : START byte  = 0xAA
//   Byte 1..16    : RESULT      = 16 bytes (ciphertext or plaintext)
//   Byte 17       : END byte    = 0x55
//
// KEY / DATA BYTE ORDER: BIG-ENDIAN. The FIRST byte received becomes the
// MOST-significant byte of the key/data bus, matching standard AES/FIPS-197
// notation (e.g. key hex string "000102...0f" -> byte 0x00 is the top byte).
// Unused upper bits of aes_key (for 128/192-bit keys) are zero-padded.
//
// IMPLEMENTATION NOTE: byte accumulation uses shift registers (shift left,
// insert new byte at the bottom) rather than indexing into the register at
// a variable (runtime) bit position. A variable-position write into a wide
// register forces the synthesizer to build a full decoder across every bit
// of that register -- this is what caused a severe F7/F8 Mux over-utilization
// failure during Place Design in an earlier version of this file (~22,000
// F7 Muxes from this module alone, on a device with only 16,300 available).
// Shifting is simple adjacent-bit movement and costs a small fraction of
// that logic.

module controller (
  input             clk,
  input             rst_n,          // active-low system reset

  // From uart_rx
  input             rx_dv,
  input      [7:0]  rx_byte,

  // To uart_tx
  output reg        tx_dv,
  output reg [7:0]  tx_byte,
  input             tx_done,
  input             tx_active,

  // Status outputs (wire to LEDs for a visible debug indicator)
  output reg        led_busy,
  output reg        led_error,

  // To aes_wrapper
  output reg          aes_start,
  output reg  [1:0]   aes_mode,
  output reg           aes_op,
  output reg  [255:0] aes_key,
  output reg  [127:0] aes_data_in,
  input       [127:0] aes_data_out,
  input                aes_done
);

  localparam BYTE_START = 8'hAA;
  localparam BYTE_END   = 8'h55;

  localparam S_IDLE       = 4'd0;
  localparam S_MODE       = 4'd1;
  localparam S_OP         = 4'd2;
  localparam S_KEY        = 4'd3;
  localparam S_DATA       = 4'd4;
  localparam S_ENDBYTE    = 4'd5;
  localparam S_START_PROC = 4'd6;
  localparam S_WAIT_DONE  = 4'd7;
  localparam S_SEND_START = 4'd8;
  localparam S_SEND_DATA  = 4'd9;
  localparam S_SEND_END   = 4'd10;
  localparam S_SEND_WAIT  = 4'd11;

  reg [3:0]   state;
  reg [5:0]   byte_cnt;
  reg [5:0]   key_len_bytes;   // 16 / 24 / 32
  reg [4:0]   send_idx;        // 0..16 (16 data bytes, then check for end)
  reg [127:0] tx_shift;        // holds the result while it's shifted out byte-by-byte

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= S_IDLE;
      tx_dv         <= 1'b0;
      aes_start     <= 1'b0;
      led_busy      <= 1'b0;
      led_error     <= 1'b0;
      byte_cnt      <= 6'd0;
      key_len_bytes <= 6'd16;
      send_idx      <= 5'd0;
      aes_key       <= 256'b0;
      aes_data_in   <= 128'b0;
      aes_mode      <= 2'd0;
      aes_op        <= 1'b0;
      tx_byte       <= 8'h00;
      tx_shift      <= 128'b0;
    end else begin
      // defaults: these are single-cycle pulses unless re-asserted below
      tx_dv     <= 1'b0;
      aes_start <= 1'b0;

      case (state)

        S_IDLE: begin
          led_busy  <= 1'b0;
          byte_cnt  <= 6'd0;
          if (rx_dv && (rx_byte == BYTE_START)) begin
            led_error <= 1'b0;
            state     <= S_MODE;
          end
        end

        S_MODE: begin
          if (rx_dv) begin
            aes_mode <= rx_byte[1:0];
            case (rx_byte[1:0])
              2'd0: key_len_bytes <= 6'd16;
              2'd1: key_len_bytes <= 6'd24;
              2'd2: key_len_bytes <= 6'd32;
              default: key_len_bytes <= 6'd16;
            endcase
            state <= S_OP;
          end
        end

        S_OP: begin
          if (rx_dv) begin
            aes_op      <= rx_byte[0];
            byte_cnt    <= 6'd0;
            led_busy    <= 1'b1;
            aes_key     <= 256'b0;   // clear so unused upper bits (128/192) are zero
            aes_data_in <= 128'b0;
            state       <= S_KEY;
          end
        end

        S_KEY: begin
          // Shift left 8, insert new byte at the bottom. After key_len_bytes
          // shifts, byte 0 (first received) sits at the top of the occupied
          // range and the last byte received sits at aes_key[7:0] -- standard
          // big-endian AES key convention.
          if (rx_dv) begin
            aes_key <= {aes_key[247:0], rx_byte};
            if (byte_cnt == key_len_bytes - 1'b1) begin
              byte_cnt <= 6'd0;
              state    <= S_DATA;
            end else begin
              byte_cnt <= byte_cnt + 1'b1;
            end
          end
        end

        S_DATA: begin
          if (rx_dv) begin
            aes_data_in <= {aes_data_in[119:0], rx_byte};
            if (byte_cnt == 6'd15) begin
              byte_cnt <= 6'd0;
              state    <= S_ENDBYTE;
            end else begin
              byte_cnt <= byte_cnt + 1'b1;
            end
          end
        end

        S_ENDBYTE: begin
          if (rx_dv) begin
            if (rx_byte == BYTE_END) begin
              state <= S_START_PROC;
            end else begin
              // Framing error: end byte didn't match. Abort and flag it.
              led_error <= 1'b1;
              led_busy  <= 1'b0;
              state     <= S_IDLE;
            end
          end
        end

        S_START_PROC: begin
          aes_start <= 1'b1;
          state     <= S_WAIT_DONE;
        end

        S_WAIT_DONE: begin
          if (aes_done) begin
            tx_shift <= aes_data_out;   // capture the result once, before shifting it out
            send_idx <= 5'd0;
            state    <= S_SEND_START;
          end
        end

        S_SEND_START: begin
          if (!tx_active) begin
            tx_byte <= BYTE_START;
            tx_dv   <= 1'b1;
            state   <= S_SEND_WAIT;
          end
        end

        S_SEND_WAIT: begin
          if (tx_done) begin
            if (send_idx == 5'd16)
              state <= S_SEND_END;
            else
              state <= S_SEND_DATA;
          end
        end

        S_SEND_DATA: begin
          // Send the current top byte (MSB-first, matching the receive
          // convention), then shift left so the next byte is on top next time.
          if (!tx_active) begin
            tx_byte  <= tx_shift[127:120];
            tx_shift <= {tx_shift[119:0], 8'h00};
            tx_dv    <= 1'b1;
            send_idx <= send_idx + 1'b1;
            state    <= S_SEND_WAIT;
          end
        end

        S_SEND_END: begin
          if (!tx_active) begin
            tx_byte  <= BYTE_END;
            tx_dv    <= 1'b1;
            led_busy <= 1'b0;
            state    <= S_IDLE;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
