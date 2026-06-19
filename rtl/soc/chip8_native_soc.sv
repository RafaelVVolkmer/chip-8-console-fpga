// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_native_soc.sv
// -----------------------------------------------------------------------------
// @brief Native SoC integration wrapper.
// =============================================================================
//
// Responsibilities:
// - Compose the CHIP-8 system for the native board target.
// - Expose board-specific IO and clock/reset wiring.
// - Keep integration concerns out of the leaf blocks.
//
// Characteristics:
// - Board-specific SoC shell.
// - Carries only platform wiring and composition.
// - Reuses the same reusable core and peripherals.
//
// Design notes:
// - Keep platform-specific pins and clocks visible.
// =============================================================================
`default_nettype none

module chip8_soc #(
  parameter int CLK_HZ = 6000000,
  parameter int TICK_HZ = chip8_config_pkg::CHIP8_TIMER_HZ,
  parameter bit TRAP_ILLEGAL = 1'b0,
  parameter chip8_core_pkg::chip8_illegal_policy_t ILLEGAL_POLICY =
    chip8_core_pkg::ILLEGAL_AS_NOP
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        cpu_enable_i,
  input  logic [15:0] keys_i,
  input  logic        rom_load_valid_i,
  output logic        rom_load_ready_o,
  input  logic [11:0] rom_load_offset_i,
  input  logic [7:0]  rom_load_data_i,
  output logic        display_valid_o,
  output logic [5:0]  display_x_o,
  output logic [4:0]  display_y_o,
  output logic        display_pixel_o,
  input  logic [10:0] framebuffer_scan_addr_i,
  output logic        framebuffer_scan_pixel_o,
  output logic [2047:0] framebuffer_o,
  output logic [11:0] pc_o,
  output logic [31:0] debug_status_o,
  output logic [31:0] scb_hfsr_o,
  output logic [31:0] scb_cfsr_o,
  output logic [31:0] scb_mmfar_o,
  output logic [31:0] scb_bfar_o,
  output logic [31:0] scb_shcsr_o,
  output logic [31:0] scb_dfsr_o,
  output logic [31:0] scb_afsr_o,
  output logic        sound_active_o,
  output logic        halted_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [15:0] keys_sync;
  logic [15:0] keys_stable;

  chip8_key_sync u_key_sync (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .keys_async_i(keys_i),
    .keys_sync_o(keys_sync)
  );

  chip8_key_debounce u_key_debounce (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .keys_i(keys_sync),
    .keys_o(keys_stable)
  );

  chip8_core #(
    .CLK_HZ(CLK_HZ),
    .TICK_HZ(TICK_HZ),
    .TRAP_ILLEGAL(TRAP_ILLEGAL),
    .ILLEGAL_POLICY(ILLEGAL_POLICY)
  ) u_core (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .cpu_enable_i(cpu_enable_i),
    .keys_i(keys_stable),
    .rom_load_valid_i(rom_load_valid_i),
    .rom_load_ready_o(rom_load_ready_o),
    .rom_load_offset_i(rom_load_offset_i),
    .rom_load_data_i(rom_load_data_i),
    .display_valid_o(display_valid_o),
    .display_x_o(display_x_o),
    .display_y_o(display_y_o),
    .display_pixel_o(display_pixel_o),
    .framebuffer_scan_addr_i(framebuffer_scan_addr_i),
    .framebuffer_scan_pixel_o(framebuffer_scan_pixel_o),
    .framebuffer_o(framebuffer_o),
    .pc_o(pc_o),
    .debug_status_o(debug_status_o),
    .scb_hfsr_o(scb_hfsr_o),
    .scb_cfsr_o(scb_cfsr_o),
    .scb_mmfar_o(scb_mmfar_o),
    .scb_bfar_o(scb_bfar_o),
    .scb_shcsr_o(scb_shcsr_o),
    .scb_dfsr_o(scb_dfsr_o),
    .scb_afsr_o(scb_afsr_o),
    .sound_active_o(sound_active_o),
    .halted_o(halted_o)
  );
endmodule

`default_nettype wire

// EOF
