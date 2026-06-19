// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// tang_nano_9k_clock_reset.sv
// -----------------------------------------------------------------------------
// @brief Board integration wrapper for Tang Nano 9K board.
// =============================================================================
//
// Responsibilities:
// - Bind board clocks, resets and IO to the reusable SoC.
// - Instantiate the platform-specific top-level glue.
// - Keep board-only policy out of the core RTL.
//
// Characteristics:
// - Top-level integration only.
// - Contains no architectural CPU state.
// - Separates board glue from reusable blocks.
//
// Design notes:
// - Keep the board pin contract obvious.
// =============================================================================
`default_nettype none

module tang_nano_9k_clock_reset (
  input  logic clk_27mhz_i,
  input  logic reset_button_ni,
  output logic soc_clk_o,
  output logic video_clk_o,
  output logic soc_rst_no
);
  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign soc_clk_o   = clk_27mhz_i;
  assign video_clk_o = clk_27mhz_i;

  chip8_reset_controller u_reset_controller (
    .clk_i(clk_27mhz_i),
    .ext_rst_ni(reset_button_ni),
    .pll_locked_i(1'b1),
    .dap_reset_i(1'b0),
    .watchdog_reset_i(1'b0),
    .fatal_error_i(1'b0),
    .soc_rst_no(soc_rst_no),
    .cpu_rst_no(),
    .video_rst_no(),
    .debug_rst_no(),
    .storage_rst_no()
  );
endmodule

`default_nettype wire

// EOF
