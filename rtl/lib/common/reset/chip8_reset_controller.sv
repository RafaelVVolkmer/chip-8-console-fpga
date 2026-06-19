// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_reset_controller.sv
// -----------------------------------------------------------------------------
// @brief Reset synchronizer and distributor.
// =============================================================================
//
// Responsibilities:
// - Generate clean reset release behavior.
// - Fan reset out to local domains safely.
// - Keep reset polarity and timing explicit.
//
// Characteristics:
// - Clocked reset helper.
// - Small state machine or synchronizer chain.
// - Used by top-level integration blocks.
//
// Design notes:
// - Name each reset domain and release condition.
// =============================================================================
`default_nettype none

module chip8_reset_controller (
  input  logic clk_i,
  input  logic ext_rst_ni,
  input  logic pll_locked_i,
  input  logic dap_reset_i,
  input  logic watchdog_reset_i,
  input  logic fatal_error_i,
  output logic soc_rst_no,
  output logic cpu_rst_no,
  output logic video_rst_no,
  output logic debug_rst_no,
  output logic storage_rst_no
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic rst_req_n;
  logic [3:0] rst_sync_q;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign rst_req_n = ext_rst_ni && pll_locked_i && !dap_reset_i &&
    !watchdog_reset_i && !fatal_error_i;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i or negedge rst_req_n) begin
    if (!rst_req_n) begin
      rst_sync_q <= '0;
    end else begin
      rst_sync_q <= {rst_sync_q[2:0], 1'b1};
    end
  end

  assign soc_rst_no = rst_sync_q[3];
  assign cpu_rst_no = rst_sync_q[3];
  assign video_rst_no = rst_sync_q[3];
  assign debug_rst_no = rst_sync_q[3];
  assign storage_rst_no = rst_sync_q[3];

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_ff @(posedge clk_i) begin
    if ($initstate) begin
      assume (rst_sync_q == 4'h0);
    end
  end
`endif
endmodule

`default_nettype wire

// EOF
