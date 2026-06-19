# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

## Xilinx Artix-7 reference constraints.
## Pinout follows the Digilent Arty A7 clock, reset, UART and PMOD naming.
## Check PMOD mappings against the concrete carrier before programming.

set_property PACKAGE_PIN E3 [get_ports clk_100mhz_i]
set_property IOSTANDARD LVCMOS33 [get_ports clk_100mhz_i]
create_clock -period 10.000 -name clk_100mhz_i [get_ports clk_100mhz_i]

set_property PACKAGE_PIN C2 [get_ports reset_ni]
set_property IOSTANDARD LVCMOS33 [get_ports reset_ni]

set_property PACKAGE_PIN H5 [get_ports {led_o[0]}]
set_property PACKAGE_PIN J5 [get_ports {led_o[1]}]
set_property PACKAGE_PIN T9 [get_ports {led_o[2]}]
set_property PACKAGE_PIN T10 [get_ports {led_o[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_o[*]}]

set_property PACKAGE_PIN D10 [get_ports usb_uart_rx_i]
set_property PACKAGE_PIN A9 [get_ports usb_uart_tx_o]
set_property IOSTANDARD LVCMOS33 [get_ports usb_uart_rx_i]
set_property IOSTANDARD LVCMOS33 [get_ports usb_uart_tx_o]

set_property PACKAGE_PIN D9 [get_ports irq_o]
set_property PACKAGE_PIN U16 [get_ports sound_o]
set_property IOSTANDARD LVCMOS33 [get_ports irq_o]
set_property IOSTANDARD LVCMOS33 [get_ports sound_o]

set_property PACKAGE_PIN G13 [get_ports {keypad_cols_i[0]}]
set_property PACKAGE_PIN B11 [get_ports {keypad_cols_i[1]}]
set_property PACKAGE_PIN A11 [get_ports {keypad_cols_i[2]}]
set_property PACKAGE_PIN D12 [get_ports {keypad_cols_i[3]}]
set_property PACKAGE_PIN D13 [get_ports {keypad_rows_o[0]}]
set_property PACKAGE_PIN B18 [get_ports {keypad_rows_o[1]}]
set_property PACKAGE_PIN A18 [get_ports {keypad_rows_o[2]}]
set_property PACKAGE_PIN K16 [get_ports {keypad_rows_o[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {keypad_cols_i[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {keypad_rows_o[*]}]

set_property PACKAGE_PIN E15 [get_ports sd_clk_o]
set_property PACKAGE_PIN E16 [get_ports sd_cmd_o]
set_property PACKAGE_PIN D15 [get_ports {sd_dat_i[0]}]
set_property PACKAGE_PIN C15 [get_ports {sd_dat_i[1]}]
set_property PACKAGE_PIN J17 [get_ports {sd_dat_i[2]}]
set_property PACKAGE_PIN J18 [get_ports {sd_dat_i[3]}]
set_property PACKAGE_PIN K15 [get_ports {sd_dat_out_o[0]}]
set_property PACKAGE_PIN J15 [get_ports {sd_dat_out_o[1]}]
set_property PACKAGE_PIN G17 [get_ports {sd_dat_out_o[2]}]
set_property PACKAGE_PIN G18 [get_ports {sd_dat_out_o[3]}]
set_property PACKAGE_PIN U12 [get_ports {sd_dat_oe_o[0]}]
set_property PACKAGE_PIN V12 [get_ports {sd_dat_oe_o[1]}]
set_property PACKAGE_PIN V10 [get_ports {sd_dat_oe_o[2]}]
set_property PACKAGE_PIN V11 [get_ports {sd_dat_oe_o[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports sd_clk_o]
set_property IOSTANDARD LVCMOS33 [get_ports sd_cmd_o]
set_property IOSTANDARD LVCMOS33 [get_ports {sd_dat_i[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sd_dat_out_o[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sd_dat_oe_o[*]}]
