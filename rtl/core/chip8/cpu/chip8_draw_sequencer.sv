// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_draw_sequencer.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 sprite draw sequencer.
// =============================================================================
//
// Responsibilities:
// - Walk sprite rows and bits for the XOR draw operation.
// - Emit address and collision context for the framebuffer path.
// - Keep sprite iteration separate from core state handling.
//
// Characteristics:
// - Small FSM with explicit row and bit counters.
// - Optimized for deterministic draw timing.
// - Works with the framebuffer write path only.
//
// Design notes:
// - Do not hide draw cadence inside the core control FSM.
// =============================================================================
`default_nettype none

module chip8_draw_sequencer (
  input  logic        draw_byte_valid_i,
  input  logic [7:0]  sprite_byte_i,
  input  logic [7:0]  mem_sprite_byte_i,
  input  logic [2:0]  draw_bit_i,
  input  logic [3:0]  draw_row_i,
  input  logic [3:0]  draw_n_i,
  input  logic        collision_accum_i,
  input  logic        sprite_pixel_on_i,
  input  logic        display_collision_i,
  output logic [7:0]  sprite_byte_d_o,
  output logic        draw_byte_valid_d_o,
  output logic [2:0]  draw_bit_d_o,
  output logic [3:0]  draw_row_d_o,
  output logic        collision_accum_d_o,
  output logic        v_we_o,
  output logic [3:0]  v_waddr_o,
  output logic [7:0]  v_wdata_o,
  output chip8_core_pkg::chip8_state_t state_d_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic draw_last_bit;
  logic draw_last_row;
  logic draw_done;

  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [2:0] CHIP8_SPRITE_LAST_BIT = 3'd7;
  localparam logic [3:0] CHIP8_SPRITE_EMPTY_HEIGHT = 4'h0;
  localparam logic [3:0] CHIP8_VF_INDEX = 4'hf;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign draw_last_bit = draw_bit_i == CHIP8_SPRITE_LAST_BIT;
  assign draw_last_row = (draw_n_i == CHIP8_SPRITE_EMPTY_HEIGHT) |
    (draw_row_i == (draw_n_i - 1'b1));
  assign draw_done = draw_last_bit & draw_last_row;

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    sprite_byte_d_o = sprite_byte_i;
    draw_byte_valid_d_o = draw_byte_valid_i;
    draw_bit_d_o = draw_bit_i;
    draw_row_d_o = draw_row_i;
    collision_accum_d_o = collision_accum_i;
    v_we_o = '0;
    v_waddr_o = '0;
    v_wdata_o = '0;
    state_d_o = chip8_core_pkg::CHIP8_CORE_PKG_STATE_DRAW;

    if (!draw_byte_valid_i) begin
      sprite_byte_d_o = mem_sprite_byte_i;
      draw_byte_valid_d_o = '1;
    end else begin
      collision_accum_d_o = collision_accum_i |
        (sprite_pixel_on_i & display_collision_i);
      draw_bit_d_o = draw_last_bit ? '0 : draw_bit_i + 1'b1;
      draw_row_d_o = (draw_last_bit & !draw_last_row) ?
        draw_row_i + 1'b1 : draw_row_i;
      state_d_o = draw_done ? chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH :
        chip8_core_pkg::CHIP8_CORE_PKG_STATE_DRAW;

      if (draw_last_bit && !draw_last_row) begin
        draw_byte_valid_d_o = '0;
        state_d_o = chip8_core_pkg::CHIP8_CORE_PKG_STATE_MEM_READ;
      end

      if (draw_done) begin
        draw_byte_valid_d_o = '0;
        v_we_o = '1;
        v_waddr_o = CHIP8_VF_INDEX;
        v_wdata_o = {7'h00, collision_accum_d_o};
      end
    end
  end
endmodule

`default_nettype wire

// EOF
