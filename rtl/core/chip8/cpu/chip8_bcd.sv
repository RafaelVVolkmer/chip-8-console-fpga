// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_bcd.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 BCD converter.
// =============================================================================
//
// Responsibilities:
// - Convert an 8-bit value to packed decimal digits.
// - Support the `Fx33` instruction path.
// - Keep digit extraction visible for formal checks.
//
// Characteristics:
// - Pure combinational arithmetic.
// - No hidden state or sequential dependence.
// - Shares the same digit semantics as the writer block.
//
// Design notes:
// - Keep digit ordering explicit and documented.
// =============================================================================
`default_nettype none

module chip8_bcd (
  input  logic [7:0] binary_i,
  output logic [3:0] hundreds_o,
  output logic [3:0] tens_o,
  output logic [3:0] ones_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int unsigned BCD_INPUT_WIDTH = 8;
  localparam int unsigned BCD_DIGIT_WIDTH = 4;
  localparam int unsigned BCD_SHIFT_WIDTH =
    BCD_INPUT_WIDTH + (3 * BCD_DIGIT_WIDTH);
  localparam logic [BCD_DIGIT_WIDTH-1:0] BCD_ADJUST_THRESHOLD = 4'd5;
  localparam logic [BCD_DIGIT_WIDTH-1:0] BCD_ADJUST_BIAS      = 4'd3;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [19:0] shift;

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    shift = {{(BCD_SHIFT_WIDTH-BCD_INPUT_WIDTH){1'b0}}, binary_i};
    for (int idx = '0; idx < BCD_INPUT_WIDTH; idx++) begin
      shift[19:16] = shift[19:16] + (
        {BCD_DIGIT_WIDTH{shift[19:16] >= BCD_ADJUST_THRESHOLD}} &
        BCD_ADJUST_BIAS);
      shift[15:12] = shift[15:12] + (
        {BCD_DIGIT_WIDTH{shift[15:12] >= BCD_ADJUST_THRESHOLD}} &
        BCD_ADJUST_BIAS);
      shift[11:8] = shift[11:8] + (
        {BCD_DIGIT_WIDTH{shift[11:8] >= BCD_ADJUST_THRESHOLD}} &
        BCD_ADJUST_BIAS);
      shift = shift << 1;
    end
  end

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign hundreds_o = shift[19:16];
  assign tens_o = shift[15:12];
  assign ones_o = shift[11:8];

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_comb begin
    assert (hundreds_o <= 4'd9);
    assert (tens_o <= 4'd9);
    assert (ones_o <= 4'd9);
  end
`endif
endmodule

`default_nettype wire

// EOF
