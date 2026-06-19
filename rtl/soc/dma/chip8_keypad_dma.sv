// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_keypad_dma.sv
// -----------------------------------------------------------------------------
// @brief Keypad DMA helper.
// =============================================================================
//
// Responsibilities:
// - Convert keypad state into a DMA-friendly stream.
// - Keep bitmaps and handshakes visible to software.
// - Separate keypad sampling from bus policy.
//
// Characteristics:
// - Peripheral bridge helper.
// - Used for event capture and register access.
// - Keeps keypad timing explicit.
//
// Design notes:
// - Keep FIFO pop and status update points named.
// =============================================================================
`default_nettype none

module chip8_keypad_dma #(
  parameter int EVENT_WIDTH = 16,
  parameter int DEPTH = 16
) (
  input  logic                   clk_i,
  input  logic                   rst_ni,
  input  logic                   enable_i,
  input  logic                   event_valid_i,
  input  logic [EVENT_WIDTH-1:0] event_data_i,
  input  logic                   pop_i,
  output logic [EVENT_WIDTH-1:0] pop_data_o,
  output logic                   empty_o,
  output logic                   full_o,
  output logic                   overflow_o,
  output logic                   done_irq_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int PTR_WIDTH = (DEPTH <= 2) ? 1 : $clog2(DEPTH);
  localparam logic [PTR_WIDTH:0] DEPTH_COUNT = (PTR_WIDTH + 1)'(DEPTH);

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [EVENT_WIDTH-1:0] mem_q [0:DEPTH-1];
  logic [PTR_WIDTH-1:0]   wr_ptr_q;
  logic [PTR_WIDTH-1:0]   rd_ptr_q;
  logic [PTR_WIDTH:0]     count_q;
  logic                   push_fire;
  logic                   pop_fire;
  logic                   overflow_fire;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign empty_o    = (count_q == '0);
  assign full_o     = (count_q == DEPTH_COUNT);
  assign pop_data_o = mem_q[rd_ptr_q];
  assign push_fire = enable_i && event_valid_i && !full_o;
  assign pop_fire = enable_i && pop_i && !empty_o;
  assign overflow_fire = enable_i && event_valid_i && full_o;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : keypad_dma_ring_ff
    if (!rst_ni) begin
      wr_ptr_q   <= '0;
      rd_ptr_q   <= '0;
      count_q    <= '0;
      overflow_o <= '0;
      done_irq_o <= '0;
    end else begin
      done_irq_o <= '0;
      if (!enable_i) begin
        wr_ptr_q   <= '0;
        rd_ptr_q   <= '0;
        count_q    <= '0;
        overflow_o <= '0;
      end else begin
        // Push and pop are treated as independent predicates. The
        // occupancy update is a small signed delta, which keeps the
        // ring-buffer accounting deterministic under simultaneous
        // producer and consumer activity.
        // Ref: Ladner/Fischer, parallel prefix computation, JACM,
        // 1980.
        if (push_fire) begin
          mem_q[wr_ptr_q] <= event_data_i;
          wr_ptr_q        <= wr_ptr_q + {{(PTR_WIDTH-1){1'b0}}, 1'b1};
        end
        if (pop_fire) begin
          rd_ptr_q <= rd_ptr_q + {{(PTR_WIDTH-1){1'b0}}, 1'b1};
        end

        count_q <= count_q +
          {{PTR_WIDTH{1'b0}}, push_fire} -
          {{PTR_WIDTH{1'b0}}, pop_fire};
        done_irq_o <= push_fire;
        overflow_o <= overflow_o | overflow_fire;

      end
    end
  end
endmodule

`default_nettype wire

// EOF
