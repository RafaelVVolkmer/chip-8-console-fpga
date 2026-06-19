// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_instruction_trace.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 Instruction trace.
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

module chip8_instruction_trace (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        valid_i,
  input  logic [11:0] pc_i,
  input  logic [15:0] opcode_i,
  output logic        valid_o,
  output logic [27:0] trace_word_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic        valid_q;
  logic        valid_d;
  logic [27:0] trace_word_q;
  logic [27:0] trace_word_d;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign valid_d = valid_i;
  assign trace_word_d = ({28{valid_i}} & {pc_i, opcode_i}) |
    ({28{!valid_i}} & trace_word_q);
  assign valid_o = valid_q;
  assign trace_word_o = trace_word_q;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      valid_q <= '0;
      trace_word_q <= '0;
    end else begin
      valid_q <= valid_d;
      trace_word_q <= trace_word_d;
    end
  end
endmodule

`default_nettype wire

// EOF
