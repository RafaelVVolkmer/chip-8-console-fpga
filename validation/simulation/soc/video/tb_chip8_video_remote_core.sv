// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// tb_chip8_video_remote_core.sv
// -----------------------------------------------------------------------------
// @brief SoC integration wrapper for Tb chip8 video remote core.
// =============================================================================
//
// Responsibilities:
// - Compose the CPU, memory, video, storage and debug blocks.
// - Route clocks, resets, buses and interrupts explicitly.
// - Keep integration policy outside leaf modules.
//
// Characteristics:
// - Top-level composition block.
// - Owns interconnect, not leaf algorithms.
// - Bridges board pins to reusable modules.
//
// Design notes:
// - Keep subsystem windows and clock domains named.
// =============================================================================
`default_nettype none

module tb_chip8_video_remote_core;
  // ------------------------------------------------------------
  // Testbench signals
  // ------------------------------------------------------------

  logic clk;
  logic rst_n;
  logic [2047:0] framebuffer;
  logic [31:0] rdata;
  logic ready;
  logic hdmi_clk_p;
  logic hdmi_clk_n;
  logic [2:0] hdmi_data_p;
  logic [2:0] hdmi_data_n;
  logic lcd_spi_sck;
  logic lcd_spi_mosi;
  logic lcd_spi_dc;
  logic lcd_spi_cs;
  logic lcd_spi_rst;
  logic lcd_rgb_de;
  logic lcd_rgb_hsync;
  logic lcd_rgb_vsync;
  logic [5:0] lcd_rgb_r;
  logic [5:0] lcd_rgb_g;
  logic [5:0] lcd_rgb_b;
  logic irq_frame_done;
  logic irq_vblank;
  logic irq_error;
  logic dma_done;

  // ------------------------------------------------------------
  // Stimulus and checks
  // ------------------------------------------------------------

  initial clk = '0;
  always #5 clk = ~clk;

  chip8_video_remote_core u_dut (
  .clk_i(clk),
  .rst_ni(rst_n),
  .framebuffer_i(framebuffer),
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
  .irq_frame_done_o(irq_frame_done),
  .irq_vblank_o(irq_vblank),
  .irq_error_o(irq_error),
  .dma_done_o(dma_done),
  .reg_valid_i(1'b1),
  .reg_we_i(1'b0),
  .reg_addr_i(8'h04),
  .reg_wdata_i(32'h0),
  .reg_wstrb_i(4'h0),
  .reg_ready_o(ready),
  .reg_rdata_o(rdata)
  );

  // ------------------------------------------------------------
  // Testbench tasks
  // ------------------------------------------------------------

  task automatic tick;
  @(posedge clk);
  #1;
  endtask

  initial begin : video_remote_smoke
  rst_n = '0;
  framebuffer = '0;
  framebuffer[0] = '1;
  framebuffer[2047] = '1;
  repeat (3) tick();
  rst_n = '1;
  repeat (40) begin
    tick();
    assert (hdmi_clk_p == ~hdmi_clk_n);
    assert (hdmi_data_p == ~hdmi_data_n);
    assert (ready);
    assert (!irq_error);
  end
  assert (lcd_spi_rst);
  assert (lcd_rgb_r <= 6'h3f && lcd_rgb_g <= 6'h3f && lcd_rgb_b <= 6'h3f);
  $finish;
  end
endmodule

`default_nettype wire

// EOF
