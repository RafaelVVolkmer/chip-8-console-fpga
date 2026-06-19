// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_timer_60hz.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 timer Timer 60hz.
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

module chip8_timer_60hz #(
  parameter int unsigned CLK_HZ = 6000000,
  parameter int unsigned TICK_HZ = 60
) (
  input  logic clk_i,
  input  logic rst_ni,
  output logic tick_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int unsigned TIMER_60HZ_TICKS_PER_PULSE =
    ((CLK_HZ / TICK_HZ) < 1) ? 1 : (CLK_HZ / TICK_HZ);
  localparam int unsigned TIMER_60HZ_LAST_COUNT =
    TIMER_60HZ_TICKS_PER_PULSE - 1;
  localparam int unsigned TIMER_60HZ_COUNTER_WIDTH = 32;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [TIMER_60HZ_COUNTER_WIDTH-1:0] counter_q;
  logic [TIMER_60HZ_COUNTER_WIDTH-1:0] counter_d;
  logic tick_q;
  logic tick_d;
  logic counter_last;
  logic [TIMER_60HZ_COUNTER_WIDTH-1:0] counter_inc;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign counter_last = counter_q == TIMER_60HZ_COUNTER_WIDTH'(
    TIMER_60HZ_LAST_COUNT);
  assign counter_inc = counter_q + 1'b1;
  assign counter_d = {TIMER_60HZ_COUNTER_WIDTH{!counter_last}} &
    counter_inc;
  assign tick_d = counter_last;
  assign tick_o = tick_q;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      counter_q <= '0;
      tick_q <= '0;
    end else begin
      counter_q <= counter_d;
      tick_q <= tick_d;
    end
  end

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      assert(counter_q <= TIMER_60HZ_COUNTER_WIDTH'(
        TIMER_60HZ_LAST_COUNT));
    end
  end
`endif
endmodule

`default_nettype wire

// EOF
