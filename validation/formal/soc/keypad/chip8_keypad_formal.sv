// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_keypad_formal.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 Keypad.
// =============================================================================
//
// Responsibilities:
// - Instantiate the DUT and constrain reset and legal inputs.
// - Assert interface contracts and temporal properties.
// - Keep proof-only state local to the harness.
//
// Characteristics:
// - Non-synthesizable proof wrapper.
// - Uses anyseq/anyconst stimuli and assertions.
// - Intended for bounded or induction proofs.
//
// Design notes:
// - Keep assumptions minimal and assertions local.
// =============================================================================
`default_nettype none

module chip8_keypad_formal (
  input logic clk_i,
  input logic rst_ni
);
  (* anyseq *) logic [3:0]  cols;
  // ------------------------------------------------------------
  // Testbench signals
  // ------------------------------------------------------------

  logic [3:0]  rows;
  logic [15:0] key_bitmap;
  logic        key_valid;
  logic [3:0]  key_code;
  logic        irq_event;
  logic        irq_overflow;
  logic        dma_done;
  (* anyseq *) logic        reg_valid;
  (* anyseq *) logic        reg_we;
  (* anyseq *) logic [7:0]  reg_addr;
  (* anyseq *) logic [31:0] reg_wdata;
  (* anyseq *) logic [3:0]  reg_wstrb;
  logic        reg_ready;
  logic [31:0] reg_rdata;
  logic        past_valid;

  // ------------------------------------------------------------
  // Stimulus and checks
  // ------------------------------------------------------------

  initial past_valid = '0;

  chip8_keypad_remote_core #(
  .CLK_HZ(16),
  .SCAN_HZ(1)
  ) u_keypad (
  .clk_i(clk_i),
  .rst_ni(rst_ni),
  .rows_o(rows),
  .cols_i(cols),
  .key_bitmap_o(key_bitmap),
  .key_valid_o(key_valid),
  .key_code_o(key_code),
  .irq_event_o(irq_event),
  .irq_overflow_o(irq_overflow),
  .dma_done_o(dma_done),
  .reg_valid_i(reg_valid),
  .reg_we_i(reg_we),
  .reg_addr_i(reg_addr),
  .reg_wdata_i(reg_wdata),
  .reg_wstrb_i(reg_wstrb),
  .reg_ready_o(reg_ready),
  .reg_rdata_o(reg_rdata)
  );

  // ------------------------------------------------------------
  // Clocked testbench procedures
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : formal_ff
  past_valid <= '1;
  if (!past_valid) begin
    assume (!rst_ni);
  end else begin
    assume (rst_ni);
  end

  if (past_valid && $past(rst_ni) && rst_ni) begin
    assert (reg_ready == reg_valid);
    assert (key_code <= 4'hf);
    assert (key_valid == (key_bitmap != 16'h0000));
    assert (rows != 4'b0000);
  end
  if (reg_valid && !reg_we && reg_addr == 8'h00) begin
    assert (reg_rdata[31:3] == 29'h0);
  end
  end
endmodule

`default_nettype wire

// EOF
