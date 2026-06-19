// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_memory_map.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 memory map constants.
// =============================================================================
//
// Responsibilities:
// - Define the ROM, RAM and I/O address boundaries.
// - Keep the map shared between RTL and formal code.
// - Avoid duplicating address literals across modules.
//
// Characteristics:
// - Compile-time constants only.
// - Pure mapping contract for the system.
// - Used by fetch, loader and bus decode.
//
// Design notes:
// - Keep the I/O base and RAM limit named explicitly.
// =============================================================================
`default_nettype none

module chip8_memory_map (
  input  logic [11:0] addr_i,
  output logic        is_font_o,
  output logic        is_program_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic use_bounds;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign use_bounds = ^{chip8_memmap_pkg::CHIP8_FONT_BASE,
    chip8_memmap_pkg::CHIP8_RAM_LAST};

  assign is_font_o = (addr_i <= chip8_memmap_pkg::CHIP8_FONT_LAST) | (
    use_bounds & 1'b0);
  assign is_program_o = (addr_i >= chip8_memmap_pkg::CHIP8_ROM_BASE_ADDR) | (
    use_bounds & 1'b0);
endmodule

`default_nettype wire

// EOF
