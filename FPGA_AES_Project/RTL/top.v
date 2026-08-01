// top.v
// Top-level for AT-STLN-ARTIX 7-001 (Xilinx XC7A35T-FTG256-1)
//
// WIRING (see aes_uart_top.xdc for the confirmed pin assignments):
//   - uart_rx_pin / uart_tx_pin are mapped to PMOD IO_1 (R3) / IO_0 (T2).
//     The manual's dedicated UART header section was unavailable, and the
//     onboard USB-C (J1/FT232H) is JTAG-only per section 4.1 of the manual,
//     so this uses the PMOD connector instead. Wire an EXTERNAL 3.3V
//     USB-to-TTL serial adapter to those two PMOD pins (cross TX/RX,
//     common GND) rather than to the onboard USB-C port.
//   - rst_n is mapped to slide switch SS0 (pin C9) rather than a push
//     button, since the reset button's FPGA pin wasn't in the manual
//     excerpt provided.

module top (
  input        clk_24mhz,
  input        rst_n,          // active-low reset, wired to slide switch SS0
  input        uart_rx_pin,    // wired to PMOD IO_1 (R3)
  output       uart_tx_pin,    // wired to PMOD IO_0 (T2)
  output [7:0] led,
  output       lcd_rs,         // wired to G4 (manual section 4.3)
  output       lcd_rw,         // wired to H3
  output       lcd_en,         // wired to E1
  output [7:0] lcd_d           // wired to G2,G1,H5,H4,J5,J4,H2,H1 (D0..D7)
);

  wire        rx_dv;
  wire [7:0]  rx_byte;

  wire        tx_dv;
  wire [7:0]  tx_byte;
  wire        tx_active;
  wire        tx_done;

  wire         aes_start;
  wire [1:0]   aes_mode;
  wire         aes_op;
  wire [255:0] aes_key;
  wire [127:0] aes_data_in;
  wire [127:0] aes_data_out;
  wire         aes_done;

  wire led_busy, led_error;

  assign led[0]   = led_busy;
  assign led[1]   = led_error;
  assign led[7:2] = 6'b0;

  uart_rx #(.CLKS_PER_BIT(208)) u_uart_rx (
    .clk       (clk_24mhz),
    .rst_n     (rst_n),
    .rx_serial (uart_rx_pin),
    .rx_dv     (rx_dv),
    .rx_byte   (rx_byte)
  );

  uart_tx #(.CLKS_PER_BIT(208)) u_uart_tx (
    .clk       (clk_24mhz),
    .rst_n     (rst_n),
    .tx_dv     (tx_dv),
    .tx_byte   (tx_byte),
    .tx_active (tx_active),
    .tx_serial (uart_tx_pin),
    .tx_done   (tx_done)
  );

  // keep_hierarchy prevents the synthesizer from merging/retiming logic
  // across this instance boundary during optimization. Added specifically
  // to diagnose an F7/F8 Mux over-utilization DRC failure where the
  // hierarchical utilization report kept attributing ~22,000 F7 Muxes to
  // u_controller even after controller.v was rewritten to remove the
  // variable-indexed writes that originally caused it -- this checks
  // whether cross-boundary optimization was mislabeling AES-core logic
  // under u_controller in the report.
  (* keep_hierarchy = "yes" *) controller u_controller (
    .clk          (clk_24mhz),
    .rst_n        (rst_n),
    .rx_dv        (rx_dv),
    .rx_byte      (rx_byte),
    .tx_dv        (tx_dv),
    .tx_byte      (tx_byte),
    .tx_done      (tx_done),
    .tx_active    (tx_active),
    .led_busy     (led_busy),
    .led_error    (led_error),
    .aes_start    (aes_start),
    .aes_mode     (aes_mode),
    .aes_op       (aes_op),
    .aes_key      (aes_key),
    .aes_data_in  (aes_data_in),
    .aes_data_out (aes_data_out),
    .aes_done     (aes_done)
  );

  (* keep_hierarchy = "yes" *) aes_wrapper u_aes_wrapper (
    .clk      (clk_24mhz),
    .rst      (rst_n),      // aes_enc/aes_dec are also active-low reset
    .start    (aes_start),
    .mode     (aes_mode),
    .op       (aes_op),
    .key      (aes_key),
    .data_in  (aes_data_in),
    .data_out (aes_data_out),
    .done     (aes_done)
  );

  // LCD status display: line 1 = selected mode, line 2 = READY/BUSY/ERROR.
  // Reuses aes_mode, led_busy, led_error -- no new signals needed from
  // the controller.
  lcd_driver u_lcd_driver (
    .clk         (clk_24mhz),
    .rst_n       (rst_n),
    .mode        (aes_mode),
    .busy        (led_busy),
    .error_flag  (led_error),
    .lcd_rs      (lcd_rs),
    .lcd_rw      (lcd_rw),
    .lcd_en      (lcd_en),
    .lcd_d       (lcd_d)
  );

endmodule
