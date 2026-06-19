// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_video_formal.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 video subsystem.
// =============================================================================
//
// Responsibilities:
// - Instantiate the DUT and constrain reset and legal inputs.
// - Assert interface contracts and temporal properties.
// - Keep proof-only state local to the harness.
//
// Characteristics:
// - Non-synthesizable proof wrapper.
// - Uses anyseq/anyconst stimuli and assertions.
// - Intended for bounded or induction proofs.
//
// Design notes:
// - Keep assumptions minimal and assertions local.
// =============================================================================
`default_nettype none

module chip8_video_formal (
  input logic clk_i,
  input logic rst_ni
);
  localparam logic [7:0] VIDEO_BACKEND_OFFSET = 8'h08;
  localparam logic [7:0] VIDEO_SCALE_OFFSET = 8'h0c;
  localparam logic [7:0] VIDEO_CTRL_OFFSET = 8'h00;
  localparam logic [7:0] DCMIPP_CAPTURE_OFFSET = 8'h14;
  localparam logic [5:0] FORMAL_VIDEO_LAST_X = 6'd63;
  localparam logic [4:0] FORMAL_VIDEO_LAST_Y = 5'd31;
  localparam logic [7:0] FORMAL_VIDEO_SCALE_AUTO = 8'h00;

  (* anyseq *) logic [2047:0] framebuffer;
  (* anyseq *) logic          reg_valid;
  (* anyseq *) logic          reg_we;
  (* anyseq *) logic [7:0]    reg_addr;
  (* anyseq *) logic [31:0]   reg_wdata;
  (* anyseq *) logic [3:0]    reg_wstrb;
  (* anyseq *) logic          cam_valid;
  (* anyseq *) logic          cam_hsync;
  (* anyseq *) logic          cam_vsync;
  (* anyseq *) logic [7:0]    cam_ycbcr;
  // ------------------------------------------------------------
  // Testbench signals
  // ------------------------------------------------------------

  logic          reg_ready;
  logic [31:0]   reg_rdata;
  (* anyseq *) logic          frame_done;
  (* anyseq *) logic          vblank;
  (* anyseq *) logic          error;
  logic          enable;
  logic          force_refresh;
  logic          invert;
  logic          test_pattern;
  logic [1:0]    backend;
  logic [7:0]    scale;
  logic          irq_frame_done;
  logic          irq_vblank;
  logic          irq_error;
  logic          pixel_valid;
  logic [5:0]    pixel_x;
  logic [4:0]    pixel_y;
  logic          pixel;
  logic          dma_frame_done;
  logic [2047:0] dma2d_framebuffer;
  logic          dma2d_irq_done;
  logic          dma2d_irq_error;
  logic [31:0]   dma2d_rdata;
  logic [2047:0] dcmipp_framebuffer;
  logic          dcmipp_pixel_valid;
  logic [5:0]    dcmipp_pixel_x;
  logic [4:0]    dcmipp_pixel_y;
  logic          dcmipp_pixel;
  logic          dcmipp_irq_frame;
  logic [31:0]   dcmipp_rdata;
  logic          past_valid;

  // ------------------------------------------------------------
  // Stimulus and checks
  // ------------------------------------------------------------

  initial past_valid = '0;

  chip8_video_regs #(
  .DEFAULT_BACKEND(chip8_axi_pkg::VIDEO_BACKEND_HDMI),
  .DEFAULT_SCALE(10)
  ) u_regs (
  .clk_i(clk_i),
  .rst_ni(rst_ni),
  .frame_done_i(frame_done),
  .vblank_i(vblank),
  .error_i(error),
  .enable_o(enable),
  .force_refresh_o(force_refresh),
  .invert_o(invert),
  .test_pattern_o(test_pattern),
  .backend_o(backend),
  .scale_o(scale),
  .irq_frame_done_o(irq_frame_done),
  .irq_vblank_o(irq_vblank),
  .irq_error_o(irq_error),
  .reg_valid_i(reg_valid),
  .reg_we_i(reg_we),
  .reg_addr_i(reg_addr),
  .reg_wdata_i(reg_wdata),
  .reg_wstrb_i(reg_wstrb),
  .reg_ready_o(reg_ready),
  .reg_rdata_o(reg_rdata)
  );

  chip8_video_dma_reader u_reader (
  .clk_i(clk_i),
  .rst_ni(rst_ni),
  .enable_i(enable),
  .restart_i(force_refresh),
  .framebuffer_i(framebuffer),
  .pixel_valid_o(pixel_valid),
  .pixel_x_o(pixel_x),
  .pixel_y_o(pixel_y),
  .pixel_o(pixel),
  .frame_done_o(dma_frame_done)
  );

  chip8_dma2d_engine u_dma2d (
  .clk_i(clk_i),
  .rst_ni(rst_ni),
  .framebuffer_i(framebuffer),
  .framebuffer_o(dma2d_framebuffer),
  .irq_done_o(dma2d_irq_done),
  .irq_error_o(dma2d_irq_error),
  .reg_valid_i(reg_valid),
  .reg_we_i(reg_we),
  .reg_addr_i(reg_addr),
  .reg_wdata_i(reg_wdata),
  .reg_wstrb_i(reg_wstrb),
  .reg_ready_o(),
  .reg_rdata_o(dma2d_rdata)
  );

  chip8_dcmipp_pipeline u_dcmipp (
  .clk_i(clk_i),
  .rst_ni(rst_ni),
  .framebuffer_i(dma2d_framebuffer),
  .framebuffer_o(dcmipp_framebuffer),
  .pixel_valid_o(dcmipp_pixel_valid),
  .pixel_x_o(dcmipp_pixel_x),
  .pixel_y_o(dcmipp_pixel_y),
  .pixel_o(dcmipp_pixel),
  .irq_frame_o(dcmipp_irq_frame),
  .cam_valid_i(cam_valid),
  .cam_hsync_i(cam_hsync),
  .cam_vsync_i(cam_vsync),
  .cam_ycbcr_i(cam_ycbcr),
  .reg_valid_i(reg_valid),
  .reg_we_i(reg_we),
  .reg_addr_i(reg_addr),
  .reg_wdata_i(reg_wdata),
  .reg_wstrb_i(reg_wstrb),
  .reg_ready_o(),
  .reg_rdata_o(dcmipp_rdata)
  );

  // ------------------------------------------------------------
  // Clocked testbench procedures
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : formal_ff
  past_valid <= '1;
  if (!past_valid) begin
    assume (!rst_ni);
  end else begin
    assume (rst_ni);
  end

  if (reg_valid && reg_we && reg_addr == VIDEO_BACKEND_OFFSET &&
      reg_wstrb[0]) begin
    assume (reg_wdata[1:0] <= 2'd2);
  end
  if (reg_valid && reg_we && reg_addr == VIDEO_SCALE_OFFSET &&
      reg_wstrb[0]) begin
    assume (reg_wdata[7:0] != FORMAL_VIDEO_SCALE_AUTO);
  end
  if (reg_valid && reg_we && reg_addr == DCMIPP_CAPTURE_OFFSET &&
      reg_wstrb[0]) begin
    assume (reg_wdata[3:2] <= 2'd1);
    assume (reg_wdata[5:4] <= 2'd1);
  end

  if (past_valid && $past(rst_ni) && rst_ni) begin
    assert (reg_ready == reg_valid);
    assert (backend <= 2'd2);
    assert (scale != FORMAL_VIDEO_SCALE_AUTO);
    assert (pixel_x <= FORMAL_VIDEO_LAST_X);
    assert (pixel_y <= FORMAL_VIDEO_LAST_Y);
    assert (!pixel_valid || enable);
    assert (dcmipp_pixel_x <= FORMAL_VIDEO_LAST_X);
    assert (dcmipp_pixel_y <= FORMAL_VIDEO_LAST_Y);
    assert (!dcmipp_pixel_valid || dcmipp_framebuffer <=
    {2048{1'b1}});
    assert (!(dma2d_irq_done && dma2d_irq_error));
  end
  if (reg_valid && !reg_we && reg_addr == VIDEO_CTRL_OFFSET) begin
    assert (reg_rdata[31:4] == 28'h0);
  end
  end

  logic unused_formal;
  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign unused_formal = invert ^ test_pattern ^ irq_vblank ^ pixel ^
  dma_frame_done ^ dma2d_rdata[0] ^ dcmipp_rdata[0] ^ dcmipp_pixel ^
  dcmipp_irq_frame;
endmodule

`default_nettype wire

// EOF
