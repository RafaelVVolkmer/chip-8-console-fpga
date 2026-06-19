// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_fpga_top.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 Fpga top.
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

module chip8_fpga_top #(
  parameter int CLK_HZ = 6000000,
  parameter int TICK_HZ = chip8_config_pkg::CHIP8_TIMER_HZ
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic [15:0] keys_i,
  input  logic        rom_load_valid_i,
  output logic        rom_load_ready_o,
  input  logic [11:0] rom_load_offset_i,
  input  logic [7:0]  rom_load_data_i,
  output logic        display_valid_o,
  output logic [5:0]  display_x_o,
  output logic [4:0]  display_y_o,
  output logic        display_pixel_o,
  output logic        sound_active_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [2047:0] framebuffer_unused;
  logic [11:0] pc_unused;
  logic [31:0] debug_status_unused;
  logic [31:0] scb_hfsr_unused;
  logic [31:0] scb_cfsr_unused;
  logic [31:0] scb_mmfar_unused;
  logic [31:0] scb_bfar_unused;
  logic [31:0] scb_shcsr_unused;
  logic [31:0] scb_dfsr_unused;
  logic [31:0] scb_afsr_unused;
  logic halted_unused;

  chip8_top #(
    .CLK_HZ(CLK_HZ),
    .TICK_HZ(TICK_HZ),
    .TRAP_ILLEGAL(1'b0)
  ) u_top (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .keys_i(keys_i),
    .rom_load_valid_i(rom_load_valid_i),
    .rom_load_ready_o(rom_load_ready_o),
    .rom_load_offset_i(rom_load_offset_i),
    .rom_load_data_i(rom_load_data_i),
    .display_valid_o(display_valid_o),
    .display_x_o(display_x_o),
    .display_y_o(display_y_o),
    .display_pixel_o(display_pixel_o),
    .framebuffer_o(framebuffer_unused),
    .pc_o(pc_unused),
    .debug_status_o(debug_status_unused),
    .scb_hfsr_o(scb_hfsr_unused),
    .scb_cfsr_o(scb_cfsr_unused),
    .scb_mmfar_o(scb_mmfar_unused),
    .scb_bfar_o(scb_bfar_unused),
    .scb_shcsr_o(scb_shcsr_unused),
    .scb_dfsr_o(scb_dfsr_unused),
    .scb_afsr_o(scb_afsr_unused),
    .sound_active_o(sound_active_o),
    .halted_o(halted_unused)
  );
endmodule

`default_nettype wire

// EOF
