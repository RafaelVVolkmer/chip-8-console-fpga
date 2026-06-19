// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_control.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 instruction control sequencer.
// =============================================================================
//
// Responsibilities:
// - Turn decoded instruction classes into register, memory and timer actions.
// - Sequence traps, skips and write-back points.
// - Keep control state explicit for synthesis and review.
//
// Characteristics:
// - Synchronous control FSM.
// - Separates instruction class handling from datapath math.
// - Meant to stay small and inspectable.
//
// Design notes:
// - Use local names for every architectural transition.
// =============================================================================
`default_nettype none

module chip8_control (
  input  logic [3:0] opcode_class_i,
  input  logic [7:0] kk_i,
  input  chip8_core_pkg::chip8_decoded_t decoded_i,
  output logic       is_draw_o,
  output logic       is_wait_key_o,
  output logic       is_timer_write_o,
  output logic       is_memory_burst_o,
  output logic       uses_memory_o,
  output logic       uses_display_o,
  output logic       uses_timer_o,
  output logic       uses_keypad_o,
  output logic       legal_o,
  output chip8_core_pkg::chip8_uop_t first_uop_o
);

  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [7:0] CHIP8_CONTROL_WAIT_KEY_IMM = 8'h0a;
  localparam logic [7:0] CHIP8_CONTROL_WRITE_DELAY_TIMER_IMM = 8'h15;
  localparam logic [7:0] CHIP8_CONTROL_WRITE_SOUND_TIMER_IMM = 8'h18;
  localparam logic [7:0] CHIP8_CONTROL_STORE_REGS_IMM = 8'h55;
  localparam logic [7:0] CHIP8_CONTROL_LOAD_REGS_IMM = 8'h65;
  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign is_draw_o = opcode_class_i == chip8_isa_pkg::CHIP8_OP_DRW;
  assign is_wait_key_o =
    (opcode_class_i == chip8_isa_pkg::CHIP8_OP_MISC) &&
    (kk_i == CHIP8_CONTROL_WAIT_KEY_IMM);
  assign is_timer_write_o =
    (opcode_class_i == chip8_isa_pkg::CHIP8_OP_MISC) &&
    ((kk_i == CHIP8_CONTROL_WRITE_DELAY_TIMER_IMM) ||
     (kk_i == CHIP8_CONTROL_WRITE_SOUND_TIMER_IMM));
  assign is_memory_burst_o =
    (opcode_class_i == chip8_isa_pkg::CHIP8_OP_MISC) &&
    ((kk_i == CHIP8_CONTROL_STORE_REGS_IMM) ||
     (kk_i == CHIP8_CONTROL_LOAD_REGS_IMM));
  assign uses_memory_o = decoded_i.uses_memory;
  assign uses_display_o = decoded_i.uses_display;
  assign uses_timer_o = decoded_i.uses_timer;
  assign uses_keypad_o = decoded_i.uses_keypad;
  assign legal_o = decoded_i.legal;
  assign first_uop_o = decoded_i.first_uop;

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    assert (legal_o == decoded_i.legal);
    assert (first_uop_o == decoded_i.first_uop);
    if (is_draw_o) assert (uses_display_o);
    if (is_timer_write_o) assert (uses_timer_o);
    if (is_wait_key_o) assert (uses_keypad_o);
  end
`endif
endmodule

`default_nettype wire

// EOF
