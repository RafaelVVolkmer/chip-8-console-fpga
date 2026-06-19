// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_video_accel.sv
// -----------------------------------------------------------------------------
// @brief Video accelerator.
// =============================================================================
//
// Responsibilities:
// - Expose video-related acceleration state to software.
// - Keep frame, pixel and control behavior explicit.
// - Bridge register control to the video pipeline.
//
// Characteristics:
// - Peripheral helper, not a display backend.
// - Uses synchronous status and control bits.
// - Shared by board bring-up and validation.
//
// Design notes:
// - Keep the accelerator contract narrow and named.
// =============================================================================
`default_nettype none

module chip8_video_accel #(
  parameter int DEFAULT_BACKEND = chip8_axi_pkg::VIDEO_BACKEND_HDMI
) (
  input  logic          clk_i,
  input  logic          rst_ni,
  input  logic [2047:0] framebuffer_i,
  output logic          hdmi_clk_po,
  output logic          hdmi_clk_no,
  output logic [2:0]    hdmi_data_po,
  output logic [2:0]    hdmi_data_no,
  output logic          lcd_spi_sck_o,
  output logic          lcd_spi_mosi_o,
  output logic          lcd_spi_dc_o,
  output logic          lcd_spi_cs_o,
  output logic          lcd_spi_rst_o,
  output logic          lcd_rgb_de_o,
  output logic          lcd_rgb_hsync_o,
  output logic          lcd_rgb_vsync_o,
  output logic [5:0]    lcd_rgb_r_o,
  output logic [5:0]    lcd_rgb_g_o,
  output logic [5:0]    lcd_rgb_b_o,
  output logic          irq_frame_done_o,
  output logic          irq_vblank_o,
  output logic          irq_error_o,
  output logic          dma_done_o,
  input  logic          reg_valid_i,
  input  logic          reg_we_i,
  input  logic [7:0]    reg_addr_i,
  input  logic [31:0]   reg_wdata_i,
  input  logic [3:0]    reg_wstrb_i,
  output logic          reg_ready_o,
  output logic [31:0]   reg_rdata_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------
  //
  // None. Video acceleration state is contained in the remote core.

  // ------------------------------------------------------------
  // Submodule instances
  // ------------------------------------------------------------

  chip8_video_remote_core #(
    .DEFAULT_BACKEND(DEFAULT_BACKEND)
  ) u_impl (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .framebuffer_i(framebuffer_i),
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
    .irq_frame_done_o(irq_frame_done_o),
    .irq_vblank_o(irq_vblank_o),
    .irq_error_o(irq_error_o),
    .dma_done_o(dma_done_o),
    .reg_valid_i(reg_valid_i),
    .reg_we_i(reg_we_i),
    .reg_addr_i(reg_addr_i),
    .reg_wdata_i(reg_wdata_i),
    .reg_wstrb_i(reg_wstrb_i),
    .reg_ready_o(reg_ready_o),
    .reg_rdata_o(reg_rdata_o)
  );
endmodule

`default_nettype wire

// EOF
