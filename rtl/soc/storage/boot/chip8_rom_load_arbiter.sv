// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_rom_load_arbiter.sv
// -----------------------------------------------------------------------------
// @brief ROM load arbiter.
// =============================================================================
//
// Responsibilities:
// - Select the active ROM loader or writer source.
// - Keep the load path arbitration visible.
// - Avoid hidden priority between boot sources.
//
// Characteristics:
// - Small arbitration wrapper.
// - Used by boot and debug paths.
// - Only one producer should own the ROM stream.
//
// Design notes:
// - Keep source priority and handoff rules explicit.
// =============================================================================
`default_nettype none

module chip8_rom_load_arbiter (
  input  logic        boot_valid_i,
  output logic        boot_ready_o,
  input  logic [11:0] boot_offset_i,
  input  logic [7:0]  boot_data_i,
  input  logic        prog_valid_i,
  output logic        prog_ready_o,
  input  logic [11:0] prog_offset_i,
  input  logic [7:0]  prog_data_i,
  input  logic        ext_valid_i,
  output logic        ext_ready_o,
  input  logic [11:0] ext_offset_i,
  input  logic [7:0]  ext_data_i,
  output logic        rom_valid_o,
  input  logic        rom_ready_i,
  output logic [11:0] rom_offset_o,
  output logic [7:0]  rom_data_o
);
  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    rom_valid_o = '0;
    rom_offset_o = '0;
    rom_data_o = '0;
    boot_ready_o = '0;
    prog_ready_o = '0;
    ext_ready_o = '0;

    if (boot_valid_i) begin
      rom_valid_o = '1;
      rom_offset_o = boot_offset_i;
      rom_data_o = boot_data_i;
      boot_ready_o = rom_ready_i;
    end else if (prog_valid_i) begin
      rom_valid_o = '1;
      rom_offset_o = prog_offset_i;
      rom_data_o = prog_data_i;
      prog_ready_o = rom_ready_i;
    end else if (ext_valid_i) begin
      rom_valid_o = '1;
      rom_offset_o = ext_offset_i;
      rom_data_o = ext_data_i;
      ext_ready_o = rom_ready_i;
    end
  end
endmodule

`default_nettype wire

// EOF
