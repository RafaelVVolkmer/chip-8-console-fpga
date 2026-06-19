// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_prefix_count.sv
// -----------------------------------------------------------------------------
// @brief Prefix-count helper.
// =============================================================================
//
// Responsibilities:
// - Count active predicates or bits in a vector.
// - Support video scaling and similar tree reductions.
// - Keep the reduction structure synthesizable.
//
// Characteristics:
// - Combinational reduction primitive.
// - Used where prefix counts are simpler than loops.
// - Shared by video coordinate mapping.
//
// Design notes:
// - Keep the predicate width and count width explicit.
// =============================================================================
`default_nettype none

module chip8_prefix_count #(
  parameter int unsigned WIDTH = 8,
  parameter int unsigned COUNT_WIDTH = $clog2(WIDTH + 1)
) (
  input  logic [WIDTH-1:0]       predicates_i,
  output logic [COUNT_WIDTH-1:0] count_o
);
  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    count_o = '0;
    for (int unsigned idx = 0; idx < WIDTH; idx++) begin
      count_o = count_o +
        {{(COUNT_WIDTH-1){1'b0}}, predicates_i[idx]};
    end
  end

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_comb begin
    assert (count_o <= COUNT_WIDTH'(WIDTH));
  end
`endif
endmodule

`default_nettype wire

// EOF
