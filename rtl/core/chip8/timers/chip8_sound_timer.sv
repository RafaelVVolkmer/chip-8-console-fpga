// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_sound_timer.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 timer Sound timer.
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

module chip8_sound_timer (
  input  logic       clk_i,
  input  logic       rst_ni,
  input  logic       tick_60hz_i,
  input  logic       we_i,
  input  logic [7:0] wdata_i,
  output logic [7:0] value_o,
  output logic       active_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int unsigned CHIP8_TIMER_WIDTH = 8;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic timer_dec;
  logic [CHIP8_TIMER_WIDTH-1:0] value_q;
  logic [CHIP8_TIMER_WIDTH-1:0] value_d;
  logic [CHIP8_TIMER_WIDTH-1:0] dec_value;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign timer_dec = tick_60hz_i && value_q != '0;
  assign dec_value = value_q - {{(CHIP8_TIMER_WIDTH-1){1'b0}}, timer_dec};
  assign value_d = ({CHIP8_TIMER_WIDTH{we_i}} & wdata_i) |
    ({CHIP8_TIMER_WIDTH{!we_i}} & dec_value);
  assign value_o = value_q;
  assign active_o = value_q != '0;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      value_q <= '0;
    end else begin
      value_q <= value_d;
    end
  end
endmodule

`default_nettype wire

// EOF
