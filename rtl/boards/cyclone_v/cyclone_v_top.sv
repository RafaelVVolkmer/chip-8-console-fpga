// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// cyclone_v_top.sv
// -----------------------------------------------------------------------------
// @brief Board integration wrapper for Cyclone V board.
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

module cyclone_v_top #(
  parameter int CLK_HZ = cyclone_v_pkg::CYCLONE_V_CLK_HZ,
  parameter int VIDEO_BACKEND = cyclone_v_pkg::CYCLONE_V_VIDEO_BACKEND,
  parameter bit DEBUG_PROFILE = 1'b1
) (
  input  logic       clk_50mhz_i,
  input  logic       reset_ni,
  input  logic [3:0] keypad_cols_i,
  input  logic [3:0] sd_dat_i,
  input  logic       usb_uart_rx_i,
  output logic [3:0] keypad_rows_o,
  output logic       sd_clk_o,
  output logic       sd_cmd_o,
  output logic [3:0] sd_dat_out_o,
  output logic [3:0] sd_dat_oe_o,
  output logic       usb_uart_tx_o,
  output logic       sound_o,
  output logic       irq_o,
  output logic [7:0] status_led_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic          soc_rst_n;
  logic          usb_log_valid;
  logic [7:0]    usb_log_data;
  logic          hdmi_clk_p;
  logic          hdmi_clk_n;
  logic [2:0]    hdmi_data_p;
  logic [2:0]    hdmi_data_n;
  logic          lcd_spi_sck;
  logic          lcd_spi_mosi;
  logic          lcd_spi_dc;
  logic          lcd_spi_cs;
  logic          lcd_spi_rst;
  logic          lcd_rgb_de;
  logic          lcd_rgb_hsync;
  logic          lcd_rgb_vsync;
  logic [5:0]    lcd_rgb_r;
  logic [5:0]    lcd_rgb_g;
  logic [5:0]    lcd_rgb_b;
  logic [2047:0] framebuffer;
  logic [11:0]   pc;
  logic          sound_active;
  logic          halted;
  logic          dap_busy;
  logic          dap_error;
  logic          dap_locked;
  logic [23:0]   heartbeat_q;

  chip8_reset_controller u_reset_controller (
    .clk_i(clk_50mhz_i),
    .ext_rst_ni(reset_ni),
    .pll_locked_i(1'b1),
    .dap_reset_i(1'b0),
    .watchdog_reset_i(1'b0),
    .fatal_error_i(1'b0),
    .soc_rst_no(soc_rst_n),
    .cpu_rst_no(),
    .video_rst_no(),
    .debug_rst_no(),
    .storage_rst_no()
  );

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_50mhz_i) begin : heartbeat_ff
    if (!soc_rst_n) begin
      heartbeat_q <= '0;
    end else begin
      heartbeat_q <= heartbeat_q + 1'b1;
    end
  end

  chip8_usb_soc_top #(
    .CLK_HZ(CLK_HZ),
    .VIDEO_BACKEND(VIDEO_BACKEND),
    .DEBUG_PROFILE(DEBUG_PROFILE)
  ) u_usb_soc (
    .clk_i(clk_50mhz_i),
    .rst_ni(soc_rst_n),
    .keypad_cols_i(keypad_cols_i),
    .sd_dat_i(sd_dat_i),
    .usb_uart_rx_i(usb_uart_rx_i),
    .keypad_rows_o(keypad_rows_o),
    .sd_clk_o(sd_clk_o),
    .sd_cmd_o(sd_cmd_o),
    .sd_dat_out_o(sd_dat_out_o),
    .sd_dat_oe_o(sd_dat_oe_o),
    .usb_uart_tx_o(usb_uart_tx_o),
    .usb_log_valid_o(usb_log_valid),
    .usb_log_data_o(usb_log_data),
    .hdmi_clk_po(hdmi_clk_p),
    .hdmi_clk_no(hdmi_clk_n),
    .hdmi_data_po(hdmi_data_p),
    .hdmi_data_no(hdmi_data_n),
    .lcd_spi_sck_o(lcd_spi_sck),
    .lcd_spi_mosi_o(lcd_spi_mosi),
    .lcd_spi_dc_o(lcd_spi_dc),
    .lcd_spi_cs_o(lcd_spi_cs),
    .lcd_spi_rst_o(lcd_spi_rst),
    .lcd_rgb_de_o(lcd_rgb_de),
    .lcd_rgb_hsync_o(lcd_rgb_hsync),
    .lcd_rgb_vsync_o(lcd_rgb_vsync),
    .lcd_rgb_r_o(lcd_rgb_r),
    .lcd_rgb_g_o(lcd_rgb_g),
    .lcd_rgb_b_o(lcd_rgb_b),
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
  assign status_led_o = {
    irq_o,
    dap_error,
    dap_locked,
    dap_busy,
    halted,
    usb_log_valid,
    pc[0],
    heartbeat_q[23]
  };

  logic board_unused;
  assign board_unused = ^{
    usb_log_data,
    hdmi_clk_p,
    hdmi_clk_n,
    hdmi_data_p,
    hdmi_data_n,
    lcd_spi_sck,
    lcd_spi_mosi,
    lcd_spi_dc,
    lcd_spi_cs,
    lcd_spi_rst,
    lcd_rgb_de,
    lcd_rgb_hsync,
    lcd_rgb_vsync,
    lcd_rgb_r,
    lcd_rgb_g,
    lcd_rgb_b,
    framebuffer[0]
  };
endmodule

`default_nettype wire

// EOF
