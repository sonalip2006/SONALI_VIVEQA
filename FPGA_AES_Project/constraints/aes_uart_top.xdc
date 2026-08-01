## aes_uart_top.xdc
## Constraints for AT-STLN-ARTIX 7-001 (Xilinx XC7A35T-FTG256-1)
## Built from the board manual's XDC reference template (section 6).

## ---------------------------------------------------------------
## Clock (confirmed from manual, section 3.9 / section 6)
## ---------------------------------------------------------------
create_clock -period 41.667 -name sys_clk [get_ports clk_24mhz]
set_property -dict {PACKAGE_PIN D13 IOSTANDARD LVCMOS33} [get_ports clk_24mhz]

## ---------------------------------------------------------------
## UART RX/TX -- via PMOD connector (WORKAROUND)
## The manual's section 3.3 (where a dedicated UART header table should be)
## is missing/not supplied, and section 4.1 states the onboard USB-C
## (FT232H) only carries JTAG, not UART data. Rather than guess at the
## unlabeled header, this uses two PMOD pins (confirmed, section 3.7,
## Bank 34, general-purpose, no other function assigned) instead.
## Wire an EXTERNAL 3.3V USB-to-TTL serial adapter to these two PMOD pins:
##   PMOD IO_0 (pin T2) <- FPGA uart_tx_pin (adapter's RX)
##   PMOD IO_1 (pin R3) -> FPGA uart_rx_pin (adapter's TX)
## (cross TX/RX between board and adapter, common GND)
## ---------------------------------------------------------------
set_property -dict {PACKAGE_PIN T2 IOSTANDARD LVCMOS33} [get_ports uart_tx_pin]
set_property -dict {PACKAGE_PIN R3 IOSTANDARD LVCMOS33} [get_ports uart_rx_pin]

## ---------------------------------------------------------------
## Reset -- via slide switch SS0 (confirmed, manual section 3.4), used
## instead of the reset button since the button's FPGA pin isn't given
## in the manual excerpt provided.
## Flip the switch to reset the design; confirm polarity on hardware
## (rst_n is ACTIVE-LOW -- if DONE/LEDs behave backwards from expected,
## the switch's rest position may pull HIGH instead of LOW; just flip
## which physical position you treat as "reset" if so).
## ---------------------------------------------------------------
set_property -dict {PACKAGE_PIN C9 IOSTANDARD LVCMOS33} [get_ports rst_n]

## ---------------------------------------------------------------
## Status LEDs (confirmed, manual section 3.1) -- led[0]=busy, led[1]=error
## ---------------------------------------------------------------
set_property -dict {PACKAGE_PIN D5  IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN A3  IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN B4  IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN A4  IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN E6  IOSTANDARD LVCMOS33} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN C13 IOSTANDARD LVCMOS33} [get_ports {led[5]}]
set_property -dict {PACKAGE_PIN C14 IOSTANDARD LVCMOS33} [get_ports {led[6]}]
set_property -dict {PACKAGE_PIN D14 IOSTANDARD LVCMOS33} [get_ports {led[7]}]

## ---------------------------------------------------------------
## 16x2 LCD (confirmed, manual section 4.3, Bank 35, 8-bit mode)
## ---------------------------------------------------------------
set_property -dict {PACKAGE_PIN G4 IOSTANDARD LVCMOS33} [get_ports lcd_rs]
set_property -dict {PACKAGE_PIN H3 IOSTANDARD LVCMOS33} [get_ports lcd_rw]
set_property -dict {PACKAGE_PIN E1 IOSTANDARD LVCMOS33} [get_ports lcd_en]
set_property -dict {PACKAGE_PIN G2 IOSTANDARD LVCMOS33} [get_ports {lcd_d[0]}]
set_property -dict {PACKAGE_PIN G1 IOSTANDARD LVCMOS33} [get_ports {lcd_d[1]}]
set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} [get_ports {lcd_d[2]}]
set_property -dict {PACKAGE_PIN H4 IOSTANDARD LVCMOS33} [get_ports {lcd_d[3]}]
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} [get_ports {lcd_d[4]}]
set_property -dict {PACKAGE_PIN J4 IOSTANDARD LVCMOS33} [get_ports {lcd_d[5]}]
set_property -dict {PACKAGE_PIN H2 IOSTANDARD LVCMOS33} [get_ports {lcd_d[6]}]
set_property -dict {PACKAGE_PIN H1 IOSTANDARD LVCMOS33} [get_ports {lcd_d[7]}]
