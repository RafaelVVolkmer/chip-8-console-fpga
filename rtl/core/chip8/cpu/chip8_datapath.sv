// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_datapath.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 CPU datapath.
// =============================================================================
//
// Responsibilities:
// - Advance the program counter and related address state.
// - Track index, draw and load/store helper values.
// - Provide the arithmetic paths consumed by control logic.
//
// Characteristics:
// - Registers are updated on the clock edge.
// - Address math stays width-safe and explicit.
// - Shared by core execution and formal proofs.
//
// Design notes:
// - Keep address masks and PC increments named.
// =============================================================================
`default_nettype none

module chip8_datapath (
  input  logic [5:0]  draw_x_value_i,
  input  logic [4:0]  draw_y_value_i,
  input  logic [7:0]  v0_i,
  input  logic [11:0] nnn_i,
  input  logic [11:0] pc_i,
  output logic [11:0] pc_plus_2_o,
  output logic [11:0] pc_plus_4_o,
  output logic [11:0] jump_v0_o,
  output logic [5:0]  draw_x_o,
  output logic [4:0]  draw_y_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [11:0] CHIP8_DATAPATH_ADDR_MASK = 12'hfff;
  localparam logic [11:0] CHIP8_DATAPATH_NEXT_PC = 12'd2;
  localparam logic [11:0] CHIP8_DATAPATH_SKIP_PC = 12'd4;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign pc_plus_2_o = (pc_i + CHIP8_DATAPATH_NEXT_PC) &
    CHIP8_DATAPATH_ADDR_MASK;
  assign pc_plus_4_o = (pc_i + CHIP8_DATAPATH_SKIP_PC) &
    CHIP8_DATAPATH_ADDR_MASK;
  assign jump_v0_o = (nnn_i + {4'h0, v0_i}) & CHIP8_DATAPATH_ADDR_MASK;
  assign draw_x_o = draw_x_value_i;
  assign draw_y_o = draw_y_value_i;
endmodule

`default_nettype wire

// EOF
