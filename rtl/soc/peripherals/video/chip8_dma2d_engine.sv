// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_dma2d_engine.sv
// -----------------------------------------------------------------------------
// @brief Frame DMA 2D engine.
// =============================================================================
//
// Responsibilities:
// - Apply clear, fill, invert and snapshot operations to the framebuffer.
// - Expose completion and error state for software and IRQs.
// - Keep the operation rectangle and overlay behavior visible.
//
// Characteristics:
// - Sequential framebuffer engine with explicit FSM state.
// - Uses packed one-bit pixels and register-visible control.
// - Designed for deterministic frame-wide operations.
//
// Design notes:
// - Keep every register offset and operation code named.
// =============================================================================
`default_nettype none

module chip8_dma2d_engine #(
  parameter int FB_WIDTH = 64,
  parameter int FB_HEIGHT = 32,
  parameter int FB_BITS = FB_WIDTH * FB_HEIGHT
) (
  input  logic               clk_i,
  input  logic               rst_ni,
  input  logic [FB_BITS-1:0] framebuffer_i,
  output logic [FB_BITS-1:0] framebuffer_o,
  output logic               irq_done_o,
  output logic               irq_error_o,

  input  logic               reg_valid_i,
  input  logic               reg_we_i,
  input  logic [7:0]         reg_addr_i,
  input  logic [31:0]        reg_wdata_i,
  input  logic [3:0]         reg_wstrb_i,
  output logic               reg_ready_o,
  output logic [31:0]        reg_rdata_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [2:0] OP_SNAPSHOT = '0;
  localparam logic [2:0] OP_CLEAR    = 3'd1;
  localparam logic [2:0] OP_FILL     = 3'd2;
  localparam logic [2:0] OP_INVERT   = 3'd3;
  localparam int unsigned LAST_INDEX = FB_BITS - 1;
  localparam logic [7:0] DMA2D_CTRL_OFFSET = 8'h00;
  localparam logic [7:0] DMA2D_STATUS_OFFSET = 8'h04;
  localparam logic [7:0] DMA2D_COLOR_OFFSET = 8'h08;
  localparam logic [7:0] DMA2D_ORIGIN_OFFSET = 8'h0c;
  localparam logic [7:0] DMA2D_SIZE_OFFSET = 8'h10;
  localparam logic [7:0] DMA2D_INDEX_OFFSET = 8'h14;
  localparam logic [6:0] DMA2D_DEFAULT_WIDTH = FB_WIDTH[6:0];
  localparam logic [5:0] DMA2D_DEFAULT_HEIGHT = FB_HEIGHT[5:0];
  localparam int unsigned DMA2D_CTRL_START_BIT = 0;
  localparam int unsigned DMA2D_CTRL_OP_LSB = 1;
  localparam int unsigned DMA2D_CTRL_OP_MSB = 3;
  localparam int unsigned DMA2D_CTRL_OVERLAY_CLEAR_BIT = 4;
  localparam int unsigned DMA2D_COLOR_VALUE_BIT = 0;
  localparam int unsigned DMA2D_ORIGIN_X_LSB = 0;
  localparam int unsigned DMA2D_ORIGIN_X_MSB = 5;
  localparam int unsigned DMA2D_ORIGIN_Y_LSB = 8;
  localparam int unsigned DMA2D_ORIGIN_Y_MSB = 12;
  localparam int unsigned DMA2D_SIZE_WIDTH_LSB = 0;
  localparam int unsigned DMA2D_SIZE_WIDTH_MSB = 6;
  localparam int unsigned DMA2D_SIZE_HEIGHT_LSB = 8;
  localparam int unsigned DMA2D_SIZE_HEIGHT_MSB = 13;

  // ------------------------------------------------------------
  // Type declarations
  // ------------------------------------------------------------

  // DMA2D command engine state.
  //
  // Responsibilities:
  // - Run framebuffer snapshot, clear, fill and invert operations.
  // - Latch completion/error status for register reads and IRQ outputs.
  // - Keep one in-flight operation visible through a small FSM.
  typedef enum logic [1:0] {
    CHIP8_DMA2D_ENGINE_STATE_IDLE,
    CHIP8_DMA2D_ENGINE_STATE_RUN,
    CHIP8_DMA2D_ENGINE_STATE_DONE,
    CHIP8_DMA2D_ENGINE_STATE_ERROR
  } dma2d_state_t;

  dma2d_state_t state_q;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  // Distributed overlay memory that stores the DMA2D working framebuffer.
  //
  // Characteristics:
  // - One bit per CHIP-8 pixel.
  // - Updated sequentially by the command FSM.
  // - Muxed with the live framebuffer until an overlay operation completes.
  (* ram_style = "distributed", syn_ramstyle = "logic" *)
  logic              fb_ram_q [0:FB_BITS-1];
  logic              overlay_enable_q;
  logic [2:0]        op_q;
  logic              color_q;
  logic [5:0]        x_q;
  logic [4:0]        y_q;
  logic [6:0]        width_q;
  logic [5:0]        height_q;
  logic [10:0]       index_q;
  logic [5:0]        cur_x;
  logic [4:0]        cur_y;
  logic              in_rect;
  logic              start_write;
  logic              invalid_rect;
  logic              base_pixel;
  logic              op_snapshot;
  logic              op_clear;
  logic              op_fill;
  logic              op_invert;
  logic              op_passthrough;
  logic              fill_pixel;
  logic              dma2d_next_pixel;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign reg_ready_o = reg_valid_i;
  assign irq_done_o = state_q == CHIP8_DMA2D_ENGINE_STATE_DONE;
  assign irq_error_o = state_q == CHIP8_DMA2D_ENGINE_STATE_ERROR;
  assign start_write = reg_valid_i && reg_we_i &&
    reg_addr_i == DMA2D_CTRL_OFFSET &&
    reg_wstrb_i[0] && reg_wdata_i[DMA2D_CTRL_START_BIT];
  assign cur_x = index_q[5:0];
  assign cur_y = index_q[10:6];
  assign in_rect = ({1'b0, cur_x} >= {1'b0, x_q})
          && ({1'b0, cur_x} < ({1'b0, x_q} + width_q))
          && ({1'b0, cur_y} >= {1'b0, y_q})
          && ({1'b0, cur_y} < ({1'b0, y_q} + height_q));
  assign invalid_rect = (width_q == 7'd0) || (height_q == 6'd0);
  assign base_pixel = overlay_enable_q ? fb_ram_q[index_q] :
    framebuffer_i[index_q];
  assign op_snapshot = op_q == OP_SNAPSHOT;
  assign op_clear = op_q == OP_CLEAR;
  assign op_fill = op_q == OP_FILL;
  assign op_invert = op_q == OP_INVERT;
  assign op_passthrough = !(op_snapshot || op_clear || op_fill ||
    op_invert);
  assign fill_pixel = base_pixel ^ (in_rect & (base_pixel ^ color_q));
  assign dma2d_next_pixel =
    (op_snapshot & framebuffer_i[index_q]) |
    (op_clear & color_q) |
    (op_fill & fill_pixel) |
    (op_invert & !base_pixel) |
    (op_passthrough & base_pixel);

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin : dma2d_frame_mirror_comb
    for (int idx = '0; idx < FB_BITS; idx++) begin
      framebuffer_o[idx] = overlay_enable_q ? fb_ram_q[idx] :
        framebuffer_i[idx];
    end
  end

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : dma2d_ff
    if (!rst_ni) begin
      state_q          <= CHIP8_DMA2D_ENGINE_STATE_IDLE;
      for (int idx = '0; idx < FB_BITS; idx++) begin
        fb_ram_q[idx] <= '0;
      end
      overlay_enable_q <= '0;
      op_q             <= OP_SNAPSHOT;
      color_q          <= '0;
      x_q              <= '0;
      y_q              <= '0;
      width_q          <= DMA2D_DEFAULT_WIDTH;
      height_q         <= DMA2D_DEFAULT_HEIGHT;
      index_q          <= '0;
    end else begin
      if (reg_valid_i && reg_we_i) begin
        unique case (reg_addr_i)
          DMA2D_CTRL_OFFSET: if (reg_wstrb_i[0]) begin
            op_q <= reg_wdata_i[DMA2D_CTRL_OP_MSB:DMA2D_CTRL_OP_LSB];
            overlay_enable_q <= reg_wdata_i[DMA2D_CTRL_OVERLAY_CLEAR_BIT] ?
              1'b0 :
              overlay_enable_q;
          end
          DMA2D_COLOR_OFFSET: if (reg_wstrb_i[0]) begin
            color_q <= reg_wdata_i[DMA2D_COLOR_VALUE_BIT];
          end
          DMA2D_ORIGIN_OFFSET: begin
            if (reg_wstrb_i[0]) begin
              x_q <= reg_wdata_i[DMA2D_ORIGIN_X_MSB:DMA2D_ORIGIN_X_LSB];
            end
            if (reg_wstrb_i[1]) begin
              y_q <= reg_wdata_i[DMA2D_ORIGIN_Y_MSB:DMA2D_ORIGIN_Y_LSB];
            end
          end
          DMA2D_SIZE_OFFSET: begin
            if (reg_wstrb_i[0]) begin
              width_q <= reg_wdata_i[DMA2D_SIZE_WIDTH_MSB:
                                      DMA2D_SIZE_WIDTH_LSB];
            end
            if (reg_wstrb_i[1]) begin
              height_q <= reg_wdata_i[DMA2D_SIZE_HEIGHT_MSB:
                                       DMA2D_SIZE_HEIGHT_LSB];
            end
          end
          default: begin end
        endcase
      end

      unique case (state_q)
        CHIP8_DMA2D_ENGINE_STATE_IDLE: begin
          index_q <= '0;
          if (start_write) begin
            if (invalid_rect &&
                reg_wdata_i[DMA2D_CTRL_OP_MSB:DMA2D_CTRL_OP_LSB] ==
                OP_FILL) begin
              state_q <= CHIP8_DMA2D_ENGINE_STATE_ERROR;
            end else begin
              op_q <= reg_wdata_i[DMA2D_CTRL_OP_MSB:DMA2D_CTRL_OP_LSB];
              state_q <= CHIP8_DMA2D_ENGINE_STATE_RUN;
            end
          end
        end

        CHIP8_DMA2D_ENGINE_STATE_RUN: begin
          overlay_enable_q <= '1;
          // Pixel operations are predicated and OR-reduced into one
          // write datum. The sequencer still advances one address
          // per cycle, but the operation choice is dataflow instead
          // of control redirection in the hot path.
          // Ref: Mahlke et al., predicated execution support,
          // ACM/IEEE ISCA, 1992.
          fb_ram_q[index_q] <= dma2d_next_pixel;

          if (index_q == LAST_INDEX[10:0]) begin
            index_q <= '0;
            state_q <= CHIP8_DMA2D_ENGINE_STATE_DONE;
          end else begin
            index_q <= index_q + 1'b1;
          end
        end

        CHIP8_DMA2D_ENGINE_STATE_DONE: begin
          state_q <= CHIP8_DMA2D_ENGINE_STATE_IDLE;
        end

        CHIP8_DMA2D_ENGINE_STATE_ERROR: begin
          state_q <= CHIP8_DMA2D_ENGINE_STATE_IDLE;
        end

        default: state_q <= CHIP8_DMA2D_ENGINE_STATE_IDLE;
      endcase
    end
  end

  always_comb begin : dma2d_regs_read_comb
    unique case (reg_addr_i)
      DMA2D_CTRL_OFFSET: reg_rdata_o = {27'h0, overlay_enable_q, op_q, 1'b0};
      DMA2D_STATUS_OFFSET: reg_rdata_o = {28'h0, irq_error_o, irq_done_o,
        state_q};
      DMA2D_COLOR_OFFSET: reg_rdata_o = {31'h0, color_q};
      DMA2D_ORIGIN_OFFSET: reg_rdata_o = {19'h0, y_q, 2'h0, x_q};
      DMA2D_SIZE_OFFSET: reg_rdata_o = {18'h0, height_q, 1'b0, width_q};
      DMA2D_INDEX_OFFSET: reg_rdata_o = {21'h0, index_q};
      default: reg_rdata_o = '0;
    endcase
  end
endmodule

`default_nettype wire

// EOF
