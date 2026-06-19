// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_irq_controller.sv
// -----------------------------------------------------------------------------
// @brief Interrupt controller.
// =============================================================================
//
// Responsibilities:
// - Track pending interrupts and software enables.
// - Expose status and clear behavior to registers.
// - Provide a compact system IRQ summary.
//
// Characteristics:
// - Simple synchronous interrupt state block.
// - No hidden platform policy beyond decode.
// - Used by the SoC wrappers and debug paths.
//
// Design notes:
// - Keep every IRQ source mapped to a named bit.
// =============================================================================
`default_nettype none

module chip8_irq_controller #(
  parameter int IRQ_COUNT = 8
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,
  input  logic [IRQ_COUNT-1:0]  irq_sources_i,
  output logic                  irq_o,

  input  logic                  reg_valid_i,
  input  logic                  reg_we_i,
  input  logic [7:0]            reg_addr_i,
  input  logic [31:0]           reg_wdata_i,
  input  logic [3:0]            reg_wstrb_i,
  output logic                  reg_ready_o,
  output logic [31:0]           reg_rdata_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [7:0] IRQ_PENDING_OFFSET = 8'h00;
  localparam logic [7:0] IRQ_ENABLE_OFFSET = 8'h04;
  localparam logic [7:0] IRQ_STATUS_OFFSET = 8'h08;
  localparam logic [7:0] IRQ_CLEAR_OFFSET = 8'h0c;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [IRQ_COUNT-1:0] enable_q;
  logic [IRQ_COUNT-1:0] pending_q;
  logic [IRQ_COUNT-1:0] clear_mask;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign clear_mask =
    (reg_valid_i && reg_we_i && reg_addr_i == IRQ_CLEAR_OFFSET &&
    reg_wstrb_i[0]) ? reg_wdata_i[IRQ_COUNT-1:0] : '0;
  assign irq_o       = |(pending_q & enable_q);
  assign reg_ready_o = reg_valid_i;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : irq_pending_ff
    if (!rst_ni) begin
      enable_q  <= '0;
      pending_q <= '0;
    end else begin
      pending_q <= (pending_q | irq_sources_i) & ~clear_mask;

      if (reg_valid_i && reg_we_i && reg_addr_i == IRQ_ENABLE_OFFSET &&
        reg_wstrb_i[0]) begin
        enable_q <= reg_wdata_i[IRQ_COUNT-1:0];
      end
    end
  end

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin : irq_read_comb
    unique case (reg_addr_i)
      IRQ_PENDING_OFFSET: reg_rdata_o = {{(32-IRQ_COUNT){1'b0}}, pending_q};
      IRQ_ENABLE_OFFSET: reg_rdata_o = {{(32-IRQ_COUNT){1'b0}}, enable_q};
      IRQ_STATUS_OFFSET: reg_rdata_o = {{31{1'b0}}, irq_o};
      default: reg_rdata_o = '0;
    endcase
  end
endmodule

`default_nettype wire

// EOF
