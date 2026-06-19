// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_rng.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 pseudo-random generator.
// =============================================================================
//
// Responsibilities:
// - Produce a deterministic byte stream for `Cxkk`.
// - Keep the seed and recurrence visible.
// - Provide stable simulation and synthesis behavior.
//
// Characteristics:
// - Small sequential generator.
// - Designed for repeatable test outcomes.
// - Does not own wider architectural state.
//
// Design notes:
// - Keep the recurrence and seed path named.
// =============================================================================
`default_nettype none

module chip8_rng (
  input  logic       clk_i,
  input  logic       rst_ni,
  input  logic       advance_en_i,
  output logic [7:0] next_value_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [7:0] CHIP8_RNG_RESET_SEED = 8'ha5;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [7:0] lfsr_q;
  logic [7:0] lfsr_d;
  logic [7:0] lfsr_advance;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign lfsr_advance = {lfsr_q[6:0],
    lfsr_q[7] ^ lfsr_q[5] ^ lfsr_q[4] ^ lfsr_q[3]};
  assign lfsr_d = ({8{advance_en_i}} & lfsr_advance) |
    ({8{!advance_en_i}} & lfsr_q);
  assign next_value_o = lfsr_advance;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      lfsr_q <= CHIP8_RNG_RESET_SEED;
    end else begin
      lfsr_q <= lfsr_d;
    end
  end

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      assert(lfsr_q != '0);
    end
  end
`endif
endmodule

`default_nettype wire

// EOF
