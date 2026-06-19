// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_framebuffer.sv
// -----------------------------------------------------------------------------
// @brief Video Framebuffer.
// =============================================================================
//
// Responsibilities:
// - Drive scanout, capture or framebuffer transformation behavior.
// - Keep pixel timing and control paths separate.
// - Expose observable status for software and formal proofs.
//
// Characteristics:
// - Framebuffer-aware or scanout-oriented logic.
// - Uses explicit pixel geometry and timing contracts.
// - Shared across display backends and validation.
//
// Design notes:
// - Keep pixel geometry and register offsets named.
// =============================================================================
`default_nettype none

module chip8_framebuffer #(
  parameter int FRAMEBUFFER_BITS = 2048,
  parameter int FRAMEBUFFER_BANKS = 4
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        clear_i,
  input  logic        draw_we_i,
  input  logic [5:0]  draw_x_i,
  input  logic [4:0]  draw_y_i,
  input  logic [10:0] scan_addr_i,
  output logic        scan_pixel_o,
  output logic        old_pixel_o,
  output logic        new_pixel_o,
  output logic [FRAMEBUFFER_BITS - 1:0] framebuffer_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  localparam int FRAMEBUFFER_BANK_BITS = FRAMEBUFFER_BITS /
    FRAMEBUFFER_BANKS;
  localparam int FRAMEBUFFER_BANK_INDEX_BITS = $clog2(FRAMEBUFFER_BANKS);
  localparam int FRAMEBUFFER_BANK_ADDR_BITS = $clog2(FRAMEBUFFER_BANK_BITS);

  logic [FRAMEBUFFER_BANK_BITS-1:0] framebuffer_q [0:FRAMEBUFFER_BANKS-1];
  logic [FRAMEBUFFER_BANK_BITS-1:0] framebuffer_d [0:FRAMEBUFFER_BANKS-1];
  logic [FRAMEBUFFER_BITS-1:0]      framebuffer_flat;
  logic [10:0]                     pixel_index;
  logic [FRAMEBUFFER_BANK_INDEX_BITS-1:0] draw_bank;
  logic [FRAMEBUFFER_BANK_INDEX_BITS-1:0] scan_bank;
  logic [FRAMEBUFFER_BANK_ADDR_BITS-1:0] draw_bank_addr;
  logic [FRAMEBUFFER_BANK_ADDR_BITS-1:0] scan_bank_addr;
  logic draw_pixel;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign pixel_index = {draw_y_i, 6'h00} + {5'h00, draw_x_i};
  assign draw_bank = pixel_index[10:9];
  assign scan_bank = scan_addr_i[10:9];
  assign draw_bank_addr = pixel_index[8:0];
  assign scan_bank_addr = scan_addr_i[8:0];
  assign draw_pixel = framebuffer_q[draw_bank][draw_bank_addr];
  assign old_pixel_o = draw_pixel;
  assign new_pixel_o = !draw_pixel;
  assign scan_pixel_o = framebuffer_q[scan_bank][scan_bank_addr];
  assign framebuffer_o = framebuffer_flat;

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    for (int unsigned bank_idx = 0; bank_idx < FRAMEBUFFER_BANKS;
       bank_idx++) begin
      framebuffer_d[bank_idx] = framebuffer_q[bank_idx];
      framebuffer_flat[
        (bank_idx * FRAMEBUFFER_BANK_BITS) +: FRAMEBUFFER_BANK_BITS
      ] = framebuffer_q[bank_idx];
    end

    // The framebuffer is physically partitioned into independent banks.
    // Draw and scan selectors touch only one bank per access, reducing
    // local mux fanout while preserving the canonical 2048-bit view.
    // Ref: Dally, virtual-channel flow control, ACM/IEEE ISCA, 1990.
    if (clear_i) begin
      for (int unsigned bank_idx = 0; bank_idx < FRAMEBUFFER_BANKS;
         bank_idx++) begin
        framebuffer_d[bank_idx] = '0;
      end
    end else if (draw_we_i) begin
      framebuffer_d[draw_bank][draw_bank_addr] = !draw_pixel;
    end
  end

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int unsigned bank_idx = 0; bank_idx < FRAMEBUFFER_BANKS;
         bank_idx++) begin
        framebuffer_q[bank_idx] <= '0;
      end
    end else begin
      for (int unsigned bank_idx = 0; bank_idx < FRAMEBUFFER_BANKS;
         bank_idx++) begin
        framebuffer_q[bank_idx] <= framebuffer_d[bank_idx];
      end
    end
  end

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_ff @(posedge clk_i) begin
    if (rst_ni && $past(rst_ni)) begin
      assert ({1'b0, pixel_index} < FRAMEBUFFER_BITS[11:0]);
      assert ({1'b0, scan_addr_i} < FRAMEBUFFER_BITS[11:0]);
      if ($past(clear_i)) begin
        for (int unsigned bank_idx = 0; bank_idx < FRAMEBUFFER_BANKS;
           bank_idx++) begin
          assert (framebuffer_q[bank_idx] == '0);
        end
      end
      if ($past(draw_we_i && !clear_i)) begin
        assert (
          framebuffer_q[$past(draw_bank)][$past(draw_bank_addr)] ==
          !$past(draw_pixel)
        );
      end
    end
  end
`endif
endmodule

`default_nettype wire

// EOF
