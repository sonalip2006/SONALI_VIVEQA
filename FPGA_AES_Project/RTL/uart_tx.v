// uart_tx.v
// Simple 8-N-1 UART transmitter.
// Default CLKS_PER_BIT = 208 -> matches uart_rx.v for 24MHz / 115200 baud
//
// Pulse tx_dv HIGH for one clk cycle (while tx_active is LOW) to send tx_byte.
// tx_done pulses HIGH for one clk cycle when the byte has finished sending.

module uart_tx #(
  parameter CLKS_PER_BIT = 208
)(
  input            clk,
  input            rst_n,        // active-low async reset
  input            tx_dv,
  input      [7:0] tx_byte,
  output reg       tx_active,
  output reg       tx_serial,
  output reg       tx_done
);

  localparam S_IDLE       = 3'b000;
  localparam S_START_BIT  = 3'b001;
  localparam S_DATA_BITS  = 3'b010;
  localparam S_STOP_BIT   = 3'b011;
  localparam S_CLEANUP    = 3'b100;

  reg [2:0]  state;
  reg [15:0] clk_count;
  reg [2:0]  bit_index;
  reg [7:0]  tx_data;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= S_IDLE;
      tx_active <= 1'b0;
      tx_serial <= 1'b1;   // idle line is HIGH
      tx_done   <= 1'b0;
      clk_count <= 0;
      bit_index <= 0;
      tx_data   <= 8'h00;
    end else begin
      case (state)

        S_IDLE: begin
          tx_serial <= 1'b1;
          tx_done   <= 1'b0;
          clk_count <= 0;
          bit_index <= 0;
          if (tx_dv == 1'b1) begin
            tx_active <= 1'b1;
            tx_data   <= tx_byte;
            state     <= S_START_BIT;
          end else begin
            tx_active <= 1'b0;
            state     <= S_IDLE;
          end
        end

        S_START_BIT: begin
          tx_serial <= 1'b0;
          if (clk_count < CLKS_PER_BIT-1) begin
            clk_count <= clk_count + 1'b1;
          end else begin
            clk_count <= 0;
            state     <= S_DATA_BITS;
          end
        end

        S_DATA_BITS: begin
          tx_serial <= tx_data[bit_index];
          if (clk_count < CLKS_PER_BIT-1) begin
            clk_count <= clk_count + 1'b1;
          end else begin
            clk_count <= 0;
            if (bit_index < 7) begin
              bit_index <= bit_index + 1'b1;
            end else begin
              bit_index <= 0;
              state     <= S_STOP_BIT;
            end
          end
        end

        S_STOP_BIT: begin
          tx_serial <= 1'b1;
          if (clk_count < CLKS_PER_BIT-1) begin
            clk_count <= clk_count + 1'b1;
          end else begin
            tx_done   <= 1'b1;
            tx_active <= 1'b0;
            clk_count <= 0;
            state     <= S_CLEANUP;
          end
        end

        S_CLEANUP: begin
          tx_done <= 1'b0;
          state   <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
