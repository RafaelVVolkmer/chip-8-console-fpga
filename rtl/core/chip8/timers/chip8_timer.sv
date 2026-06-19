// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_timer.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 timer Timer.
// =============================================================================
//
// Responsibilities:
// - Generate or maintain timer countdown behavior.
// - Keep tick generation explicit and synchronous.
// - Expose timer value and active state cleanly.
//
// Characteristics:
// - Counter-driven sequential logic.
// - Used by delay and sound timing paths.
// - Shares the same timer rate contract.
//
// Design notes:
// - Keep timer rate, reload and tick behavior named.
// =============================================================================
`default_nettype none

module chip8_timer #(
  parameter int CLK_HZ = 6000000,
  parameter int TICK_HZ = chip8_config_pkg::CHIP8_TIMER_HZ
) (
  input  logic       clk_i,
  input  logic       rst_ni,
  input  logic       delay_we_i,
  input  logic       sound_we_i,
  input  logic [7:0] delay_wdata_i,
  input  logic [7:0] sound_wdata_i,
  output logic [7:0] delay_o,
  output logic [7:0] sound_o,
  output logic       sound_active_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic tick_60hz;

  chip8_timer_60hz #(
    .CLK_HZ(CLK_HZ),
    .TICK_HZ(TICK_HZ)
  ) u_timer_60hz (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .tick_o(tick_60hz)
  );

  chip8_delay_timer u_delay_timer (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .tick_60hz_i(tick_60hz),
    .we_i(delay_we_i),
    .wdata_i(delay_wdata_i),
    .value_o(delay_o)
  );

  chip8_sound_timer u_sound_timer (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .tick_60hz_i(tick_60hz),
    .we_i(sound_we_i),
    .wdata_i(sound_wdata_i),
    .value_o(sound_o),
    .active_o(sound_active_o)
  );
endmodule

`default_nettype wire

// EOF
