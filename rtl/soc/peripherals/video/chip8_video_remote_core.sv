// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_video_remote_core.sv
// -----------------------------------------------------------------------------
// @brief Remote video control bridge.
// =============================================================================
//
// Responsibilities:
// - Forward video commands over the remote-control path.
// - Keep transport concerns separate from video state.
// - Expose a stable remote register contract.
//
// Characteristics:
// - Peripheral bridge block.
// - No scanout logic inside the transport shim.
// - Used where video control is remoteized.
//
// Design notes:
// - Keep the transport framing and status named.
// =============================================================================
`default_nettype none

module chip8_video_remote_core #(
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
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [1:0] BACKEND_HDMI    = '0;
  localparam logic [1:0] BACKEND_LCD_SPI = 2'd1;
  localparam logic [1:0] BACKEND_LCD_RGB = 2'd2;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic enable;
  logic force_refresh;
  logic invert;
  logic test_pattern;
  logic [1:0] backend;
  logic [7:0] scale;
  logic hdmi_done;
  logic hdmi_vblank;
  logic spi_done;
  logic spi_busy;
  logic spi_error;
  logic rgb_done;
  logic rgb_vblank;
  logic dma_valid;
  logic [5:0] dma_x;
  logic [4:0] dma_y;
  logic dma_pixel;
  logic [2047:0] fb_effective;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign fb_effective = test_pattern
    ? {32{64'hffff_0000_ffff_0000}}
    : framebuffer_i;
  assign dma_done_o   = hdmi_done | spi_done | rgb_done;

  // ------------------------------------------------------------
  // Submodule instances
  // ------------------------------------------------------------

  chip8_video_regs #(
    .DEFAULT_BACKEND(DEFAULT_BACKEND),
    .DEFAULT_SCALE(10)
  ) u_regs (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .frame_done_i(dma_done_o),
    .vblank_i(hdmi_vblank | rgb_vblank),
    .error_i(spi_error),
    .enable_o(enable),
    .force_refresh_o(force_refresh),
    .invert_o(invert),
    .test_pattern_o(test_pattern),
    .backend_o(backend),
    .scale_o(scale),
    .irq_frame_done_o(irq_frame_done_o),
    .irq_vblank_o(irq_vblank_o),
    .irq_error_o(irq_error_o),
    .reg_valid_i(reg_valid_i),
    .reg_we_i(reg_we_i),
    .reg_addr_i(reg_addr_i),
    .reg_wdata_i(reg_wdata_i),
    .reg_wstrb_i(reg_wstrb_i),
    .reg_ready_o(reg_ready_o),
    .reg_rdata_o(reg_rdata_o)
  );

  chip8_video_dma_reader u_dma_reader (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .enable_i(enable),
    .restart_i(force_refresh),
    .framebuffer_i(fb_effective),
    .pixel_valid_o(dma_valid),
    .pixel_x_o(dma_x),
    .pixel_y_o(dma_y),
    .pixel_o(dma_pixel),
    .frame_done_o()
  );

  chip8_hdmi_backend u_hdmi (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .enable_i(enable && backend == BACKEND_HDMI),
    .scale_cfg_i(scale),
    .invert_i(invert),
    .framebuffer_i(fb_effective),
    .frame_done_o(hdmi_done),
    .vblank_o(hdmi_vblank),
    .hdmi_clk_po(hdmi_clk_po),
    .hdmi_clk_no(hdmi_clk_no),
    .hdmi_data_po(hdmi_data_po),
    .hdmi_data_no(hdmi_data_no)
  );

  chip8_lcd_spi_backend u_lcd_spi (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .enable_i(enable && backend == BACKEND_LCD_SPI),
    .force_frame_i(force_refresh),
    .invert_i(invert),
    .framebuffer_i(fb_effective),
    .spi_sck_o(lcd_spi_sck_o),
    .spi_mosi_o(lcd_spi_mosi_o),
    .spi_dc_o(lcd_spi_dc_o),
    .spi_cs_o(lcd_spi_cs_o),
    .spi_rst_o(lcd_spi_rst_o),
    .busy_o(spi_busy),
    .frame_done_o(spi_done),
    .error_o(spi_error)
  );

  chip8_lcd_rgb_backend u_lcd_rgb (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .enable_i(enable && backend == BACKEND_LCD_RGB),
    .scale_cfg_i(scale),
    .invert_i(invert),
    .framebuffer_i(fb_effective),
    .de_o(lcd_rgb_de_o),
    .hsync_o(lcd_rgb_hsync_o),
    .vsync_o(lcd_rgb_vsync_o),
    .rgb_r_o(lcd_rgb_r_o),
    .rgb_g_o(lcd_rgb_g_o),
    .rgb_b_o(lcd_rgb_b_o),
    .frame_done_o(rgb_done),
    .vblank_o(rgb_vblank)
  );

  // Consume logical DMA outputs so lint proves the reader is
  // connected.
  logic dma_activity_unused;
  assign dma_activity_unused = dma_valid ^ dma_pixel ^ dma_x[0] ^ dma_y[0] ^
    spi_busy;
endmodule

`default_nettype wire

// EOF
