// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_keypad_accel.sv
// -----------------------------------------------------------------------------
// @brief Keypad accelerator.
// =============================================================================
//
// Responsibilities:
// - Translate keypad input patterns into stable events.
// - Support scanning and latch behavior for the system.
// - Keep the accelerator boundary explicit.
//
// Characteristics:
// - Peripheral helper with synchronous state.
// - Pairs with the keypad matrix and registers.
// - Designed for predictable input handling.
//
// Design notes:
// - Keep scan, latch and event semantics named.
// =============================================================================
`default_nettype none

module chip8_keypad_accel #(
  parameter int CLK_HZ = 27_000_000,
  parameter int SCAN_HZ = 1_000
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  output logic [3:0]  rows_o,
  input  logic [3:0]  cols_i,
  output logic [15:0] key_bitmap_o,
  output logic        key_valid_o,
  output logic [3:0]  key_code_o,
  output logic        irq_event_o,
  output logic        irq_overflow_o,
  output logic        dma_done_o,
  input  logic        reg_valid_i,
  input  logic        reg_we_i,
  input  logic [7:0]  reg_addr_i,
  input  logic [31:0] reg_wdata_i,
  input  logic [3:0]  reg_wstrb_i,
  output logic        reg_ready_o,
  output logic [31:0] reg_rdata_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------
  //
  // None. This adapter keeps the peripheral contract flat for the SoC.

  // ------------------------------------------------------------
  // Submodule instances
  // ------------------------------------------------------------

  chip8_keypad_remote_core #(
    .CLK_HZ(CLK_HZ),
    .SCAN_HZ(SCAN_HZ)
  ) u_impl (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .rows_o(rows_o),
    .cols_i(cols_i),
    .key_bitmap_o(key_bitmap_o),
    .key_valid_o(key_valid_o),
    .key_code_o(key_code_o),
    .irq_event_o(irq_event_o),
    .irq_overflow_o(irq_overflow_o),
    .dma_done_o(dma_done_o),
    .reg_valid_i(reg_valid_i),
    .reg_we_i(reg_we_i),
    .reg_addr_i(reg_addr_i),
    .reg_wdata_i(reg_wdata_i),
    .reg_wstrb_i(reg_wstrb_i),
    .reg_ready_o(reg_ready_o),
    .reg_rdata_o(reg_rdata_o)
  );
endmodule

`default_nettype wire

// EOF
