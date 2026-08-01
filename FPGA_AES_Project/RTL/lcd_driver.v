// lcd_driver.v
// Drives the onboard 16x2 character LCD (DS1WC1602A, HD44780-compatible,
// 8-bit parallel mode per the board manual section 4.3).
//
// Shows:
//   Line 1: "MODE: AES-128/192/256"
//   Line 2: "STATUS: READY/BUSY/ERROR"
//
// DESIGN: runs the power-on init sequence once, then continuously loops
// writing both lines forever. This is simpler and more robust than an
// edge-triggered "only rewrite on change" design -- since line1_bits/
// line2_bits are computed combinationally from the live mode/busy/error
// inputs, each pass through the loop always writes whatever is currently
// true. The display updates within one loop iteration (a few
// milliseconds) of any change -- completely imperceptible to a human
// looking at the screen, and there is no risk of a stuck/stale display.
//
// Timing: uses generous, conservative delays (much longer than the
// HD44780 datasheet's minimums) since LCD update speed is irrelevant --
// correctness matters, speed does not.
// All delays given in clock cycles assuming a 24 MHz clock (~41.7ns/cycle).

module lcd_driver (
  input        clk,
  input        rst_n,      // active-low
  input  [1:0] mode,       // 0=AES-128, 1=AES-192, 2=AES-256
  input        busy,       // from controller's led_busy
  input        error_flag, // from controller's led_error

  output reg       lcd_rs,
  output reg       lcd_rw,   // always driven low (write-only)
  output reg       lcd_en,
  output reg [7:0] lcd_d
);

  // ------------------------------------------------------------------
  // Build the two 16-character display lines combinationally from the
  // current mode/status. Each string is exactly 16 ASCII characters
  // (128 bits), padded with spaces.
  // ------------------------------------------------------------------
  reg [127:0] line1_bits;
  reg [127:0] line2_bits;

  always @(*) begin
    case (mode)
      2'd0:    line1_bits = "MODE: AES-128   ";
      2'd1:    line1_bits = "MODE: AES-192   ";
      2'd2:    line1_bits = "MODE: AES-256   ";
      default: line1_bits = "MODE: -------   ";
    endcase

    if (error_flag)
      line2_bits = "STATUS: ERROR   ";
    else if (busy)
      line2_bits = "STATUS: BUSY    ";
    else
      line2_bits = "STATUS: READY   ";
  end

  // Extract character i (0=leftmost) from a 128-bit line, MSB-first
  function [7:0] char_at;
    input [127:0] line;
    input [3:0]   idx;
    begin
      char_at = line[ (15-idx)*8 +: 8 ];
    end
  endfunction

  // ------------------------------------------------------------------
  // Step sequence:
  // steps 0-4   : power-on initialization (run once after reset)
  // step  5     : set DDRAM address to line 1 start (command 0x80)
  // steps 6-21  : write the 16 characters of line 1
  // step  22    : set DDRAM address to line 2 start (command 0xC0)
  // steps 23-38 : write the 16 characters of line 2
  // after step 38: loop back to step 5 forever (skip init, which only
  //                runs once)
  // ------------------------------------------------------------------
  localparam LAST_STEP = 6'd38;
  localparam LOOP_BACK_STEP = 6'd5;

  reg [5:0]  step;
  reg [31:0] wait_cycles;
  reg        is_command;   // 1 = instruction (RS=0), 0 = data (RS=1)
  reg [7:0]  step_byte;

  always @(*) begin
    is_command  = 1'b1;
    step_byte   = 8'h00;
    wait_cycles = 32'd1000;      // ~40us default, safe for most commands/data writes

    case (step)
      6'd0:  begin step_byte = 8'h38; wait_cycles = 32'd100000; end // function set, ~4.2ms (extra safety after power-up)
      6'd1:  begin step_byte = 8'h38; wait_cycles = 32'd1000;   end // function set again (recommended)
      6'd2:  begin step_byte = 8'h0C; wait_cycles = 32'd1000;   end // display ON, cursor off, blink off
      6'd3:  begin step_byte = 8'h01; wait_cycles = 32'd40000;  end // clear display, needs ~1.52ms -- using ~1.7ms margin
      6'd4:  begin step_byte = 8'h06; wait_cycles = 32'd1000;   end // entry mode set: increment, no shift
      6'd5:  begin step_byte = 8'h80; wait_cycles = 32'd1000;   end // set DDRAM addr -> line 1 start
      6'd22: begin step_byte = 8'hC0; wait_cycles = 32'd1000;   end // set DDRAM addr -> line 2 start
      default: begin
        if (step >= 6'd6 && step <= 6'd21) begin
          is_command = 1'b0;
          step_byte  = char_at(line1_bits, step - 6'd6);
        end else if (step >= 6'd23 && step <= 6'd38) begin
          is_command = 1'b0;
          step_byte  = char_at(line2_bits, step - 6'd23);
        end
      end
    endcase
  end

  // ------------------------------------------------------------------
  // Per-step sub-FSM: SETUP (hold data stable) -> EN_HIGH (pulse) ->
  // EN_LOW (recovery + command-specific wait) -> advance to next step
  // ------------------------------------------------------------------
  localparam SUB_SETUP   = 2'd0;
  localparam SUB_EN_HIGH = 2'd1;
  localparam SUB_EN_LOW  = 2'd2;

  reg [1:0]  sub_state;
  reg [31:0] sub_counter;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      step        <= 6'd0;
      sub_state   <= SUB_SETUP;
      sub_counter <= 32'd0;
      lcd_rs      <= 1'b0;
      lcd_rw      <= 1'b0;
      lcd_en      <= 1'b0;
      lcd_d       <= 8'h00;
    end else begin
      lcd_rw <= 1'b0;  // always write

      case (sub_state)

        SUB_SETUP: begin
          lcd_rs      <= ~is_command;
          lcd_d       <= step_byte;
          lcd_en      <= 1'b0;
          sub_counter <= 32'd0;
          sub_state   <= SUB_EN_HIGH;
        end

        SUB_EN_HIGH: begin
          lcd_en <= 1'b1;
          if (sub_counter < 32'd50) begin       // ~2us enable pulse width, generous
            sub_counter <= sub_counter + 32'd1;
          end else begin
            sub_counter <= 32'd0;
            sub_state   <= SUB_EN_LOW;
          end
        end

        SUB_EN_LOW: begin
          lcd_en <= 1'b0;
          if (sub_counter < wait_cycles) begin
            sub_counter <= sub_counter + 32'd1;
          end else begin
            sub_counter <= 32'd0;
            sub_state   <= SUB_SETUP;

            if (step == LAST_STEP) begin
              step <= LOOP_BACK_STEP;   // loop forever, skip init
            end else begin
              step <= step + 6'd1;
            end
          end
        end

        default: sub_state <= SUB_SETUP;
      endcase
    end
  end

endmodule
