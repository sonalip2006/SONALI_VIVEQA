// uart_rx.v
// Simple 8-N-1 UART receiver.
// Default CLKS_PER_BIT = 208 -> 24,000,000 / 115200 = 208.33, rounded to 208
// (actual baud ~115,384 -> 0.16% error, within standard UART tolerance)
//
// rx_dv pulses HIGH for one clk cycle when a new byte (rx_byte) is ready.

module uart_rx #(
  parameter CLKS_PER_BIT = 208
)(
  input            clk,
  input            rst_n,       // active-low async reset
  input            rx_serial,
  output reg       rx_dv,
  output reg [7:0] rx_byte
);

  localparam S_IDLE       = 3'b000;
  localparam S_START_BIT  = 3'b001;
  localparam S_DATA_BITS  = 3'b010;
  localparam S_STOP_BIT   = 3'b011;
  localparam S_CLEANUP    = 3'b100;

  reg [2:0]  state;
  reg [15:0] clk_count;
  reg [2:0]  bit_index;
  reg [7:0]  rx_byte_r;

  // double-flop synchronizer to avoid metastability on the async serial input
  reg rx_data_ff1, rx_data_ff2;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_data_ff1 <= 1'b1;
      rx_data_ff2 <= 1'b1;
    end else begin
      rx_data_ff1 <= rx_serial;
      rx_data_ff2 <= rx_data_ff1;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= S_IDLE;
      clk_count <= 0;
      bit_index <= 0;
      rx_dv     <= 1'b0;
      rx_byte   <= 8'h00;
      rx_byte_r <= 8'h00;
    end else begin
      case (state)

        S_IDLE: begin
          rx_dv     <= 1'b0;
          clk_count <= 0;
          bit_index <= 0;
          if (rx_data_ff2 == 1'b0)
            state <= S_START_BIT;
          else
            state <= S_IDLE;
        end

        // Sample middle of start bit to confirm it's a real start, not a glitch
        S_START_BIT: begin
          if (clk_count == (CLKS_PER_BIT-1)/2) begin
            if (rx_data_ff2 == 1'b0) begin
              clk_count <= 0;
              state     <= S_DATA_BITS;
            end else begin
              state <= S_IDLE;
            end
          end else begin
            clk_count <= clk_count + 1'b1;
          end
        end

        // Sample each data bit at the middle of its bit period
        S_DATA_BITS: begin
          if (clk_count < CLKS_PER_BIT-1) begin
            clk_count <= clk_count + 1'b1;
          end else begin
            clk_count <= 0;
            rx_byte_r[bit_index] <= rx_data_ff2;
            if (bit_index < 7) begin
              bit_index <= bit_index + 1'b1;
            end else begin
              bit_index <= 0;
              state     <= S_STOP_BIT;
            end
          end
        end

        S_STOP_BIT: begin
          if (clk_count < CLKS_PER_BIT-1) begin
            clk_count <= clk_count + 1'b1;
          end else begin
            rx_dv     <= 1'b1;
            rx_byte   <= rx_byte_r;
            clk_count <= 0;
            state     <= S_CLEANUP;
          end
        end

        S_CLEANUP: begin
          state <= S_IDLE;
          rx_dv <= 1'b0;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
