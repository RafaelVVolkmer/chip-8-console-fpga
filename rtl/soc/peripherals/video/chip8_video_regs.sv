// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_video_regs.sv
// -----------------------------------------------------------------------------
// @brief Video register block.
// =============================================================================
//
// Responsibilities:
// - Expose video control, backend, scale and status registers.
// - Map software-visible bits to the pipeline and backends.
// - Keep status clear behavior explicit.
//
// Characteristics:
// - Synchronous register interface.
// - Owns only video control state, not scanout timing.
// - Shared by the SoC and formal harnesses.
//
// Design notes:
// - Keep the backend and scale offsets named.
// =============================================================================
`default_nettype none

module chip8_video_regs #(
  parameter int DEFAULT_BACKEND = chip8_axi_pkg::VIDEO_BACKEND_HDMI,
  parameter int DEFAULT_SCALE = 10
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        frame_done_i,
  input  logic        vblank_i,
  input  logic        error_i,
  output logic        enable_o,
  output logic        force_refresh_o,
  output logic        invert_o,
  output logic        test_pattern_o,
  output logic [1:0]  backend_o,
  output logic [7:0]  scale_o,
  output logic        irq_frame_done_o,
  output logic        irq_vblank_o,
  output logic        irq_error_o,

  input  logic        reg_valid_i,
  input  logic        reg_we_i,
  input  logic [7:0]  reg_addr_i,
  input  logic [31:0] reg_wdata_i,
  input  logic [3:0]  reg_wstrb_i,
  output logic        reg_ready_o,
  output logic [31:0] reg_rdata_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [1:0] DEFAULT_BACKEND_C = DEFAULT_BACKEND[1:0];
  localparam logic [7:0] DEFAULT_SCALE_C = DEFAULT_SCALE[7:0];
  localparam logic [7:0] VIDEO_CTRL_OFFSET = 8'h00;
  localparam logic [7:0] VIDEO_STATUS_OFFSET = 8'h04;
  localparam logic [7:0] VIDEO_BACKEND_OFFSET = 8'h08;
  localparam logic [7:0] VIDEO_SCALE_OFFSET = 8'h0c;
  localparam logic [7:0] VIDEO_IRQ_ENABLE_OFFSET = 8'h20;
  localparam logic [7:0] VIDEO_STATUS_CLEAR_OFFSET = 8'h24;

  localparam int unsigned VIDEO_CTRL_ENABLE_BIT = 0;
  localparam int unsigned VIDEO_CTRL_FORCE_REFRESH_BIT = 1;
  localparam int unsigned VIDEO_CTRL_INVERT_BIT = 2;
  localparam int unsigned VIDEO_CTRL_TEST_PATTERN_BIT = 3;

  localparam int unsigned VIDEO_STATUS_ENABLE_BIT = 0;
  localparam int unsigned VIDEO_STATUS_FRAME_DONE_BIT = 1;
  localparam int unsigned VIDEO_STATUS_VBLANK_BIT = 2;
  localparam int unsigned VIDEO_STATUS_ERROR_BIT = 3;

  localparam logic [31:0] VIDEO_IRQ_ENABLE_RESET = 32'h0000_000e;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic        enable_q;
  logic        force_refresh_q;
  logic        invert_q;
  logic        test_pattern_q;
  logic [1:0]  backend_q;
  logic [7:0]  scale_q;
  logic [31:0] status_q;
  logic [31:0] irq_enable_q;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign enable_o         = enable_q;
  assign force_refresh_o  = force_refresh_q;
  assign invert_o         = invert_q;
  assign test_pattern_o   = test_pattern_q;
  assign backend_o        = backend_q;
  assign scale_o          = scale_q;
  assign reg_ready_o      = reg_valid_i;
  assign irq_frame_done_o =
    status_q[VIDEO_STATUS_FRAME_DONE_BIT] &
    irq_enable_q[VIDEO_STATUS_FRAME_DONE_BIT];
  assign irq_vblank_o = vblank_i & irq_enable_q[VIDEO_STATUS_VBLANK_BIT];
  assign irq_error_o =
    status_q[VIDEO_STATUS_ERROR_BIT] & irq_enable_q[VIDEO_STATUS_ERROR_BIT];

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : video_regs_state_ff
    if (!rst_ni) begin
      enable_q        <= '1;
      force_refresh_q <= '0;
      invert_q        <= '0;
      test_pattern_q  <= '0;
      backend_q       <= DEFAULT_BACKEND_C;
      scale_q         <= DEFAULT_SCALE_C;
      status_q        <= '0;
      irq_enable_q    <= VIDEO_IRQ_ENABLE_RESET;
    end else begin
      status_q[VIDEO_STATUS_ENABLE_BIT] <= enable_q;
      status_q[VIDEO_STATUS_FRAME_DONE_BIT] <=
        status_q[VIDEO_STATUS_FRAME_DONE_BIT] | frame_done_i;
      status_q[VIDEO_STATUS_VBLANK_BIT] <= vblank_i;
      status_q[VIDEO_STATUS_ERROR_BIT] <=
        status_q[VIDEO_STATUS_ERROR_BIT] | error_i;

      if (force_refresh_q) begin
        force_refresh_q <= '0;
      end

      if (reg_valid_i && reg_we_i) begin
        unique case (reg_addr_i)
          VIDEO_CTRL_OFFSET: if (reg_wstrb_i[0]) begin
            enable_q <= reg_wdata_i[VIDEO_CTRL_ENABLE_BIT];
            force_refresh_q <= reg_wdata_i[VIDEO_CTRL_FORCE_REFRESH_BIT];
            invert_q <= reg_wdata_i[VIDEO_CTRL_INVERT_BIT];
            test_pattern_q <= reg_wdata_i[VIDEO_CTRL_TEST_PATTERN_BIT];
          end
          VIDEO_BACKEND_OFFSET: if (reg_wstrb_i[0]) begin
            backend_q <= reg_wdata_i[1:0];
          end
          VIDEO_SCALE_OFFSET: if (reg_wstrb_i[0]) begin
            scale_q <= reg_wdata_i[7:0];
          end
          VIDEO_IRQ_ENABLE_OFFSET: irq_enable_q <= reg_wdata_i;
          VIDEO_STATUS_CLEAR_OFFSET: status_q <= status_q & ~reg_wdata_i;
          default: begin end
        endcase
      end
    end
  end

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin : video_regs_read_comb
    unique case (reg_addr_i)
      VIDEO_CTRL_OFFSET: reg_rdata_o = {28'h0, test_pattern_q, invert_q,
        force_refresh_q, enable_q};
      VIDEO_STATUS_OFFSET: reg_rdata_o = status_q;
      VIDEO_BACKEND_OFFSET: reg_rdata_o = {30'h0, backend_q};
      VIDEO_SCALE_OFFSET: reg_rdata_o = {24'h0, scale_q};
      VIDEO_IRQ_ENABLE_OFFSET: reg_rdata_o = irq_enable_q;
      default: reg_rdata_o = '0;
    endcase
  end
endmodule

`default_nettype wire

// EOF
