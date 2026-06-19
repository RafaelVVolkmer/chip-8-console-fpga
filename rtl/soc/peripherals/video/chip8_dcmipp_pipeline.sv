// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_dcmipp_pipeline.sv
// -----------------------------------------------------------------------------
// @brief Camera capture and frame processing pipeline.
// =============================================================================
//
// Responsibilities:
// - Normalize camera pixels into the CHIP-8 framebuffer contract.
// - Apply freeze, invert, grid and capture controls.
// - Track frame hash and capture position state.
//
// Characteristics:
// - Packed frame processing with explicit scan coordinates.
// - Supports camera capture and framebuffer mirroring.
// - Registers expose pipeline state for software and formal.
//
// Design notes:
// - Keep the capture format and frame bounds named.
// =============================================================================
`default_nettype none

module chip8_dcmipp_pipeline #(
  parameter int FB_WIDTH = 64,
  parameter int FB_HEIGHT = 32,
  parameter int FB_BITS = FB_WIDTH * FB_HEIGHT
) (
  input  logic               clk_i,
  input  logic               rst_ni,
  input  logic [FB_BITS-1:0] framebuffer_i,
  output logic [FB_BITS-1:0] framebuffer_o,
  output logic               pixel_valid_o,
  output logic [5:0]         pixel_x_o,
  output logic [4:0]         pixel_y_o,
  output logic               pixel_o,
  output logic               irq_frame_o,

  input  logic               cam_valid_i,
  input  logic               cam_hsync_i,
  input  logic               cam_vsync_i,
  input  logic [7:0]         cam_ycbcr_i,

  input  logic               reg_valid_i,
  input  logic               reg_we_i,
  input  logic [7:0]         reg_addr_i,
  input  logic [31:0]        reg_wdata_i,
  input  logic [3:0]         reg_wstrb_i,
  output logic               reg_ready_o,
  output logic [31:0]        reg_rdata_o
);
  // ------------------------------------------------------------
  // Derived constants
  // ------------------------------------------------------------

  localparam int unsigned LAST_INDEX = FB_BITS - 1;
  localparam logic [1:0] FORMAT_MONO_Y = 2'd0;
  localparam logic [1:0] FORMAT_YCBCR422 = 2'd1;
  localparam logic [1:0] SOURCE_FRAMEBUFFER = 2'd0;
  localparam logic [1:0] SOURCE_CAMERA = 2'd1;
  localparam logic [7:0] DEFAULT_LUMA_THRESHOLD = 8'h80;
  localparam logic [6:0] FB_WIDTH_U7 = FB_WIDTH[6:0];
  localparam logic [5:0] FB_HEIGHT_U6 = FB_HEIGHT[5:0];
  localparam logic [5:0] FB_FIRST_X = '0;
  localparam logic [4:0] FB_FIRST_Y = '0;
  localparam logic [5:0] FB_LAST_X = 6'(FB_WIDTH - 1);
  localparam logic [4:0] FB_LAST_Y = 5'(FB_HEIGHT - 1);
  localparam logic [31:0] FRAME_HASH_RESET = 32'h1ace_cafe;
  localparam logic [7:0] DCMIPP_CTRL_OFFSET = 8'h00;
  localparam logic [7:0] DCMIPP_INDEX_OFFSET = 8'h04;
  localparam logic [7:0] DCMIPP_FRAME_COUNT_OFFSET = 8'h08;
  localparam logic [7:0] DCMIPP_PIXEL_OFFSET = 8'h0c;
  localparam logic [7:0] DCMIPP_HASH_OFFSET = 8'h10;
  localparam logic [7:0] DCMIPP_CAPTURE_OFFSET = 8'h14;
  localparam logic [7:0] DCMIPP_CAMERA_POS_OFFSET = 8'h18;
  localparam int unsigned DCMIPP_CTRL_ENABLE_BIT = 0;
  localparam int unsigned DCMIPP_CTRL_INVERT_BIT = 1;
  localparam int unsigned DCMIPP_CTRL_GRID_BIT = 2;
  localparam int unsigned DCMIPP_CTRL_FREEZE_BIT = 3;
  localparam int unsigned DCMIPP_CTRL_SNAPSHOT_BIT = 4;
  localparam int unsigned DCMIPP_CAPTURE_ENABLE_BIT = 0;
  localparam int unsigned DCMIPP_CAPTURE_CLEAR_BIT = 1;
  localparam int unsigned DCMIPP_CAPTURE_FORMAT_LSB = 2;
  localparam int unsigned DCMIPP_CAPTURE_FORMAT_MSB = 3;
  localparam int unsigned DCMIPP_CAPTURE_SOURCE_LSB = 4;
  localparam int unsigned DCMIPP_CAPTURE_SOURCE_MSB = 5;
  localparam int unsigned DCMIPP_CAPTURE_LUMA_LSB = 8;
  localparam int unsigned DCMIPP_CAPTURE_LUMA_MSB = 15;

  // ------------------------------------------------------------
  // Type declarations
  // ------------------------------------------------------------

  // Packed framebuffer vector shared by scanout, frozen snapshot and camera
  // capture paths.
  //
  // Characteristics:
  // - Bit index maps directly to the CHIP-8 64x32 pixel order.
  // - The type keeps whole-frame transforms width-safe across parameters.
  // - Used only for static frame storage and combinational frame masks.
  typedef logic [FB_BITS-1:0] framebuffer_t;

  // ------------------------------------------------------------
  // Function declarations
  // ------------------------------------------------------------

  function automatic framebuffer_t build_grid_mask();
    framebuffer_t mask;
    int unsigned  x;
    int unsigned  y;
    begin
      mask = '0;
      for (int idx = '0; idx < FB_BITS; idx++) begin
        x = idx % FB_WIDTH;
        y = idx / FB_WIDTH;
        mask[idx] = (x == 0) || (y == 0) ||
          (x == (FB_WIDTH - 1)) || (y == (FB_HEIGHT - 1));
      end
      build_grid_mask = mask;
    end
  endfunction

  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam framebuffer_t GRID_MASK = build_grid_mask();

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic        enable_q;
  logic        invert_q;
  logic        grid_q;
  logic        freeze_q;
  logic        capture_enable_q;
  logic [1:0]  capture_format_q;
  logic [1:0]  source_sel_q;
  logic [7:0]  luma_threshold_q;
  logic [10:0] index_q;
  logic [5:0]  capture_x_q;
  logic [4:0]  capture_y_q;
  logic [1:0]  ycbcr_phase_q;
  logic [31:0] frame_count_q;
  logic [31:0] frame_hash_q;
  logic [31:0] hash_d;
  framebuffer_t frozen_fb_q;
  framebuffer_t camera_fb_q;
  framebuffer_t source_fb;
  framebuffer_t base_fb;
  framebuffer_t grided_fb;
  logic [5:0] cur_x;
  logic [4:0] cur_y;
  logic       grid_pixel;
  logic       processed_pixel;
  logic       luma_sample;
  logic       luma_pixel;
  logic       capture_active;
  logic       capture_last_pixel;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  // Camera pixels are converted to the same one-bit framebuffer contract as
  // the CHIP-8 display. Keeping color interpretation before scanout makes
  // each backend a pure consumer of the normalized frame.
  //
  // The full-frame transform is expressed as vector XORs so synthesis sees a
  // fixed mask and independent bit lanes.
  assign reg_ready_o = reg_valid_i;
  assign pixel_valid_o = enable_q;
  assign pixel_x_o = cur_x;
  assign pixel_y_o = cur_y;
  assign pixel_o = framebuffer_o[index_q];
  assign cur_x = index_q[5:0];
  assign cur_y = index_q[10:6];
  assign source_fb = (source_sel_q == SOURCE_CAMERA) ? camera_fb_q :
    framebuffer_i;
  assign base_fb = freeze_q ? frozen_fb_q : source_fb;
  assign grided_fb = base_fb ^ ({FB_BITS{grid_q}} & GRID_MASK);
  assign framebuffer_o = enable_q ? (grided_fb ^ {FB_BITS{invert_q}}) :
    source_fb;
  assign grid_pixel = grid_q && (
    (cur_x == FB_FIRST_X) || (cur_y == FB_FIRST_Y) ||
    (cur_x == FB_LAST_X) || (cur_y == FB_LAST_Y)
  );
  assign processed_pixel = base_fb[index_q] ^ invert_q ^ grid_pixel;
  assign hash_d = {frame_hash_q[30:0], frame_hash_q[31] ^
    processed_pixel ^ cur_x[0] ^ cur_y[0]};
  assign luma_sample = (capture_format_q == FORMAT_MONO_Y) ||
    ((capture_format_q == FORMAT_YCBCR422) && ycbcr_phase_q[0]);
  assign luma_pixel = cam_ycbcr_i >= luma_threshold_q;
  assign capture_active = capture_enable_q && cam_valid_i && luma_sample &&
    ({1'b0, capture_x_q} < FB_WIDTH_U7) &&
    ({1'b0, capture_y_q} < FB_HEIGHT_U6);
  assign capture_last_pixel = capture_active &&
    (capture_x_q == FB_LAST_X) && (capture_y_q == FB_LAST_Y);

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : dcmipp_pipeline_ff
    if (!rst_ni) begin
      enable_q      <= '1;
      invert_q      <= '0;
      grid_q        <= '0;
      freeze_q      <= '0;
      capture_enable_q <= '0;
      capture_format_q <= FORMAT_YCBCR422;
      source_sel_q <= SOURCE_FRAMEBUFFER;
      luma_threshold_q <= DEFAULT_LUMA_THRESHOLD;
      index_q       <= '0;
      capture_x_q   <= '0;
      capture_y_q   <= '0;
      ycbcr_phase_q <= '0;
      frame_count_q <= '0;
      frame_hash_q  <= FRAME_HASH_RESET;
      frozen_fb_q   <= '0;
      camera_fb_q   <= '0;
      irq_frame_o   <= '0;
    end else begin
      irq_frame_o <= '0;

      if (reg_valid_i && reg_we_i) begin
        unique case (reg_addr_i)
          DCMIPP_CTRL_OFFSET: if (reg_wstrb_i[0]) begin
            enable_q <= reg_wdata_i[DCMIPP_CTRL_ENABLE_BIT];
            invert_q <= reg_wdata_i[DCMIPP_CTRL_INVERT_BIT];
            grid_q   <= reg_wdata_i[DCMIPP_CTRL_GRID_BIT];
            freeze_q <= reg_wdata_i[DCMIPP_CTRL_FREEZE_BIT];
            if (reg_wdata_i[DCMIPP_CTRL_SNAPSHOT_BIT]) begin
              frozen_fb_q <= source_fb;
            end
          end
          DCMIPP_HASH_OFFSET: frame_hash_q <= reg_wdata_i;
          DCMIPP_CAPTURE_OFFSET: begin
            if (reg_wstrb_i[0]) begin
              capture_enable_q <= reg_wdata_i[DCMIPP_CAPTURE_ENABLE_BIT];
              capture_format_q <= reg_wdata_i[DCMIPP_CAPTURE_FORMAT_MSB:
                                                DCMIPP_CAPTURE_FORMAT_LSB];
              source_sel_q <= reg_wdata_i[DCMIPP_CAPTURE_SOURCE_MSB:
                                           DCMIPP_CAPTURE_SOURCE_LSB];
              if (reg_wdata_i[DCMIPP_CAPTURE_CLEAR_BIT]) begin
                camera_fb_q <= '0;
              end
            end
            if (reg_wstrb_i[1]) begin
              luma_threshold_q <= reg_wdata_i[DCMIPP_CAPTURE_LUMA_MSB:
                                               DCMIPP_CAPTURE_LUMA_LSB];
            end
          end
          default: begin end
        endcase
      end

      if (cam_vsync_i) begin
        capture_x_q   <= '0;
        capture_y_q   <= '0;
        ycbcr_phase_q <= '0;
      end else if (cam_hsync_i) begin
        capture_x_q   <= '0;
        ycbcr_phase_q <= '0;
        if (capture_y_q != FB_LAST_Y) begin
          capture_y_q <= capture_y_q + 1'b1;
        end
      end else if (cam_valid_i) begin
        ycbcr_phase_q <= ycbcr_phase_q + 1'b1;
        if (capture_active) begin
          camera_fb_q[{capture_y_q, capture_x_q}] <= luma_pixel;
          capture_x_q <= capture_x_q + 1'b1;
        end
        if (capture_last_pixel) begin
          irq_frame_o <= '1;
          capture_x_q <= '0;
          capture_y_q <= '0;
        end
      end

      if (!enable_q) begin
        index_q <= '0;
      end else if (index_q == LAST_INDEX[10:0]) begin
        index_q       <= '0;
        frame_count_q <= frame_count_q + 1'b1;
        frame_hash_q  <= hash_d;
        irq_frame_o   <= '1;
      end else begin
        index_q      <= index_q + 1'b1;
        frame_hash_q <= hash_d;
      end
    end
  end

  always_comb begin : dcmipp_regs_read_comb
    unique case (reg_addr_i)
      DCMIPP_CTRL_OFFSET: reg_rdata_o = {28'h0, freeze_q, grid_q, invert_q,
        enable_q};
      DCMIPP_INDEX_OFFSET: reg_rdata_o = {21'h0, index_q};
      DCMIPP_FRAME_COUNT_OFFSET: reg_rdata_o = frame_count_q;
      DCMIPP_PIXEL_OFFSET: reg_rdata_o = {20'h0, pixel_o, pixel_y_o,
        pixel_x_o};
      DCMIPP_HASH_OFFSET: reg_rdata_o = frame_hash_q;
      DCMIPP_CAPTURE_OFFSET: reg_rdata_o = {16'h0, luma_threshold_q, 2'h0,
        source_sel_q, capture_format_q, 1'b0, capture_enable_q};
      DCMIPP_CAMERA_POS_OFFSET: reg_rdata_o = {19'h0, ycbcr_phase_q,
        capture_y_q,
        capture_x_q};
      default: reg_rdata_o = '0;
    endcase
  end
endmodule

`default_nettype wire

// EOF
