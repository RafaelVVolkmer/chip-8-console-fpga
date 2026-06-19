// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_font_rom.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 font ROM.
// =============================================================================
//
// Responsibilities:
// - Store the CHIP-8 built-in font glyphs.
// - Provide a read-only byte stream for draw opcodes.
// - Keep the font table fixed and inspectable.
//
// Characteristics:
// - Read-only lookup table.
// - One glyph per CHIP-8 character.
// - Used by the core and formal validation.
//
// Design notes:
// - Keep glyph ordering aligned with the CHIP-8 spec.
// =============================================================================
`default_nettype none

module chip8_font_rom (
  input  logic [6:0] addr_i,
  output logic [7:0] data_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [639:0] FONT_BYTES = {
    8'h80, 8'h80, 8'hf0, 8'h80, 8'hf0, 8'hf0, 8'h80, 8'hf0, 8'h80, 8'hf0,
    8'he0, 8'h90, 8'h90, 8'h90, 8'he0, 8'hf0, 8'h80, 8'h80, 8'h80, 8'hf0,
    8'he0, 8'h90, 8'he0, 8'h90, 8'he0, 8'h90, 8'h90, 8'hf0, 8'h90, 8'hf0,
    8'hf0, 8'h10, 8'hf0, 8'h90, 8'hf0, 8'hf0, 8'h90, 8'hf0, 8'h90, 8'hf0,
    8'h40, 8'h40, 8'h20, 8'h10, 8'hf0, 8'hf0, 8'h90, 8'hf0, 8'h80, 8'hf0,
    8'hf0, 8'h10, 8'hf0, 8'h80, 8'hf0, 8'h10, 8'h10, 8'hf0, 8'h90, 8'h90,
    8'hf0, 8'h10, 8'hf0, 8'h10, 8'hf0, 8'hf0, 8'h80, 8'hf0, 8'h10, 8'hf0,
    8'h70, 8'h20, 8'h20, 8'h60, 8'h20, 8'hf0, 8'h90, 8'h90, 8'h90, 8'hf0
  };

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign data_o = (addr_i < 7'd80) ? FONT_BYTES[{addr_i, 3'b000} +: 8] :
    8'h00;
endmodule

`default_nettype wire

// EOF
