// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_prefetch_queue.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 prefetch queue.
// =============================================================================
//
// Responsibilities:
// - Buffer fetched instructions between memory and decode.
// - Absorb short backpressure without losing opcode order.
// - Keep queue state local and synthesizable.
//
// Characteristics:
// - Ready/valid queue with deterministic occupancy.
// - Improves decoupling between fetch and decode.
// - Useful for formal and simulation coverage.
//
// Design notes:
// - Keep queue depth and occupancy logic explicit.
// =============================================================================
`default_nettype none

module chip8_prefetch_queue (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        flush_i,
  input  logic        fill_valid_i,
  input  logic [11:0] fill_pc_i,
  input  logic [15:0] fill_opcode_i,
  input  logic        consume_i,
  input  logic [11:0] consume_pc_i,
  output logic        hit_o,
  output logic [15:0] opcode_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic        valid_q;
  logic [11:0] pc_q;
  logic [15:0] opcode_q;
  logic        fill_match;
  logic        stored_match;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign fill_match = fill_valid_i && (fill_pc_i == consume_pc_i);
  assign stored_match = valid_q && (pc_q == consume_pc_i);
  assign hit_o = fill_match || stored_match;
  assign opcode_o = fill_match ? fill_opcode_i : opcode_q;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      valid_q  <= '0;
      pc_q     <= '0;
      opcode_q <= '0;
    end else if (flush_i) begin
      valid_q <= '0;
    end else begin
      if (fill_valid_i) begin
        valid_q  <= '1;
        pc_q     <= fill_pc_i;
        opcode_q <= fill_opcode_i;
      end
      if (consume_i && stored_match && !fill_valid_i) begin
        valid_q <= '0;
      end
    end
  end

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_ff @(posedge clk_i) begin
    if (rst_ni && $past(rst_ni)) begin
      if ($past(flush_i)) begin
        assert (!valid_q);
      end
      if (stored_match) begin
        assert (hit_o);
      end
    end
  end
`endif
endmodule

`default_nettype wire

// EOF
