// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// custom_usb_fpga_top.sv
// -----------------------------------------------------------------------------
// @brief Board integration wrapper for custom USB FPGA board.
// =============================================================================
//
// Responsibilities:
// - Bind board clocks, resets and IO to the reusable SoC.
// - Instantiate the platform-specific top-level glue.
// - Keep board-only policy out of the core RTL.
//
// Characteristics:
// - Top-level integration only.
// - Contains no architectural CPU state.
// - Separates board glue from reusable blocks.
//
// Design notes:
// - Keep the board pin contract obvious.
// =============================================================================
`default_nettype none

module custom_usb_fpga_top #(
  parameter int CLK_HZ = custom_usb_fpga_pkg::CUSTOM_USB_FPGA_CLK_HZ,
  parameter int VIDEO_BACKEND =
    custom_usb_fpga_pkg::CUSTOM_USB_FPGA_VIDEO_BACKEND,
  parameter bit DEBUG_PROFILE = 1'b1
) (
  input  logic       clk_i,
  input  logic       rst_ni,
  input  logic [3:0] keypad_cols_i,
  input  logic [3:0] sd_dat_i,
  input  logic       usb_uart_rx_i,
  output logic [3:0] keypad_rows_o,
  output logic       sd_clk_o,
  output logic       sd_cmd_o,
  output logic [3:0] sd_dat_out_o,
  output logic [3:0] sd_dat_oe_o,
  output logic       usb_uart_tx_o,
  output logic       usb_log_valid_o,
  output logic [7:0] usb_log_data_o,
  output logic       hdmi_clk_po,
  output logic       hdmi_clk_no,
  output logic [2:0] hdmi_data_po,
  output logic [2:0] hdmi_data_no,
  output logic       lcd_spi_sck_o,
  output logic       lcd_spi_mosi_o,
  output logic       lcd_spi_dc_o,
  output logic       lcd_spi_cs_o,
  output logic       lcd_spi_rst_o,
  output logic       lcd_rgb_de_o,
  output logic       lcd_rgb_hsync_o,
  output logic       lcd_rgb_vsync_o,
  output logic [5:0] lcd_rgb_r_o,
  output logic [5:0] lcd_rgb_g_o,
  output logic [5:0] lcd_rgb_b_o,
  output logic       sound_o,
  output logic       irq_o,
  output logic [3:0] status_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [2047:0] framebuffer;
  logic [11:0]   pc;
  logic          halted;
  logic          dap_busy;
  logic          dap_error;
  logic          dap_locked;
  logic          sound_active;

  // ------------------------------------------------------------
  // Submodule instances
  // ------------------------------------------------------------

  chip8_usb_soc_top #(
    .CLK_HZ(CLK_HZ),
    .VIDEO_BACKEND(VIDEO_BACKEND),
    .DEBUG_PROFILE(DEBUG_PROFILE)
  ) u_usb_soc (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .keypad_cols_i(keypad_cols_i),
    .sd_dat_i(sd_dat_i),
    .usb_uart_rx_i(usb_uart_rx_i),
    .keypad_rows_o(keypad_rows_o),
    .sd_clk_o(sd_clk_o),
    .sd_cmd_o(sd_cmd_o),
    .sd_dat_out_o(sd_dat_out_o),
    .sd_dat_oe_o(sd_dat_oe_o),
    .usb_uart_tx_o(usb_uart_tx_o),
    .usb_log_valid_o(usb_log_valid_o),
    .usb_log_data_o(usb_log_data_o),
    .hdmi_clk_po(hdmi_clk_po),
    .hdmi_clk_no(hdmi_clk_no),
    .hdmi_data_po(hdmi_data_po),
    .hdmi_data_no(hdmi_data_no),
    .lcd_spi_sck_o(lcd_spi_sck_o),
    .lcd_spi_mosi_o(lcd_spi_mosi_o),
    .lcd_spi_dc_o(lcd_spi_dc_o),
    .lcd_spi_cs_o(lcd_spi_cs_o),
    .lcd_spi_rst_o(lcd_spi_rst_o),
    .lcd_rgb_de_o(lcd_rgb_de_o),
    .lcd_rgb_hsync_o(lcd_rgb_hsync_o),
    .lcd_rgb_vsync_o(lcd_rgb_vsync_o),
    .lcd_rgb_r_o(lcd_rgb_r_o),
    .lcd_rgb_g_o(lcd_rgb_g_o),
    .lcd_rgb_b_o(lcd_rgb_b_o),
    .framebuffer_o(framebuffer),
    .pc_o(pc),
    .sound_active_o(sound_active),
    .halted_o(halted),
    .irq_o(irq_o),
    .dap_busy_o(dap_busy),
    .dap_error_o(dap_error),
    .dap_locked_o(dap_locked)
  );

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign sound_o = sound_active;
  assign status_o = {dap_error, dap_locked, dap_busy, halted};

  logic debug_unused;
  assign debug_unused = framebuffer[0] ^ pc[0];
endmodule

`default_nettype wire

// EOF
