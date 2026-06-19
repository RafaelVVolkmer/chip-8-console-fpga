// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_dma_regs.sv
// -----------------------------------------------------------------------------
// @brief DMA register block.
// =============================================================================
//
// Responsibilities:
// - Expose DMA status and IRQ enable registers.
// - Map software-visible control bits to the engine.
// - Keep status clearing behavior explicit.
//
// Characteristics:
// - Synchronous register wrapper.
// - No DMA datapath logic inside the block.
// - Connects software control to engine status.
//
// Design notes:
// - Name each status bit and clear location.
// =============================================================================
`default_nettype none

module chip8_dma_regs (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        key_dma_done_i,
  input  logic        key_dma_overflow_i,
  input  logic        video_dma_done_i,
  input  logic        video_dma_error_i,
  output logic        dma_error_irq_o,

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

  localparam logic [7:0] DMA_STATUS_OFFSET = 8'h00;
  localparam logic [7:0] DMA_IRQ_ENABLE_OFFSET = 8'h04;
  localparam logic [7:0] DMA_STATUS_CLEAR_OFFSET = 8'h08;

  localparam int unsigned DMA_STATUS_KEY_DONE_BIT = 0;
  localparam int unsigned DMA_STATUS_VIDEO_DONE_BIT = 1;
  localparam int unsigned DMA_STATUS_KEY_OVERFLOW_BIT = 16;
  localparam int unsigned DMA_STATUS_VIDEO_ERROR_BIT = 17;
  localparam int unsigned DMA_ERROR_LSB = 16;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [31:0] status_q;
  logic [31:0] enable_q;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign reg_ready_o     = reg_valid_i;
  assign dma_error_irq_o = |(status_q[31:DMA_ERROR_LSB] &
    enable_q[31:DMA_ERROR_LSB]);

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : dma_status_ff
    if (!rst_ni) begin
      status_q <= '0;
      enable_q <= '0;
    end else begin
      status_q[DMA_STATUS_KEY_DONE_BIT] <=
        status_q[DMA_STATUS_KEY_DONE_BIT] | key_dma_done_i;
      status_q[DMA_STATUS_VIDEO_DONE_BIT] <=
        status_q[DMA_STATUS_VIDEO_DONE_BIT] | video_dma_done_i;
      status_q[DMA_STATUS_KEY_OVERFLOW_BIT] <=
        status_q[DMA_STATUS_KEY_OVERFLOW_BIT] | key_dma_overflow_i;
      status_q[DMA_STATUS_VIDEO_ERROR_BIT] <=
        status_q[DMA_STATUS_VIDEO_ERROR_BIT] | video_dma_error_i;

      if (reg_valid_i && reg_we_i && reg_wstrb_i[0]) begin
        unique case (reg_addr_i)
          DMA_IRQ_ENABLE_OFFSET: enable_q <= reg_wdata_i;
          DMA_STATUS_CLEAR_OFFSET: status_q <= status_q & ~reg_wdata_i;
          default: begin end
        endcase
      end
    end
  end

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin : dma_regs_read_comb
    unique case (reg_addr_i)
      DMA_STATUS_OFFSET: reg_rdata_o = status_q;
      DMA_IRQ_ENABLE_OFFSET: reg_rdata_o = enable_q;
      default: reg_rdata_o = '0;
    endcase
  end
endmodule

`default_nettype wire

// EOF
