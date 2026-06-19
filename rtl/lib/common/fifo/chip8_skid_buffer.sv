// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_skid_buffer.sv
// -----------------------------------------------------------------------------
// @brief Ready/valid skid buffer.
// =============================================================================
//
// Responsibilities:
// - Absorb one cycle of backpressure without data loss.
// - Keep ready/valid timing local to the interface.
// - Support stable transfers across small timing gaps.
//
// Characteristics:
// - Minimal buffering primitive.
// - Used at handshakes where one extra beat matters.
// - Synthesizes as simple control and storage.
//
// Design notes:
// - Name the handshake stall point explicitly.
// =============================================================================
`default_nettype none

module chip8_skid_buffer #(
  parameter int DATA_WIDTH = 8
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,
  input  logic                  in_valid_i,
  output logic                  in_ready_o,
  input  logic [DATA_WIDTH-1:0] in_data_i,
  output logic                  out_valid_o,
  input  logic                  out_ready_i,
  output logic [DATA_WIDTH-1:0] out_data_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic                  valid_q;
  logic                  valid_d;
  logic [DATA_WIDTH-1:0] data_q;
  logic [DATA_WIDTH-1:0] data_d;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign in_ready_o  = !valid_q || out_ready_i;
  assign out_valid_o = valid_q;
  assign out_data_o  = data_q;

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    valid_d = valid_q;
    data_d = data_q;

    // The single-entry elastic stage decouples producer and consumer
    // readiness without adding a second architectural transaction. This is
    // the synchronous ready/valid analogue of the local buffering used in
    // micropipeline designs.
    if (in_ready_o) begin
      valid_d = in_valid_i;
      data_d = in_data_i;
    end
  end

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      valid_q <= '0;
      data_q  <= '0;
    end else begin
      valid_q <= valid_d;
      data_q  <= data_d;
    end
  end

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_ff @(posedge clk_i) begin
    if (rst_ni && $past(rst_ni)) begin
      assert (out_valid_o == valid_q);
      assert (out_data_o == data_q);
      assert (in_ready_o == (!valid_q || out_ready_i));
      if ($past(out_valid_o && !out_ready_i)) begin
        assert (out_valid_o);
        assert (out_data_o == $past(out_data_o));
      end
    end
  end
`endif
endmodule

`default_nettype wire

// EOF
