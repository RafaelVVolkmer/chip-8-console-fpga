// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_keypad_remote_core.sv
// -----------------------------------------------------------------------------
// @brief Remote keypad bridge.
// =============================================================================
//
// Responsibilities:
// - Forward keypad events across the remote-control path.
// - Keep the transport side separate from keypad semantics.
// - Expose stable event and bitmap state to the SoC.
//
// Characteristics:
// - Bridge block for remote input sources.
// - Uses explicit handshakes and status state.
// - Supports debug and board bring-up flows.
//
// Design notes:
// - Keep the remote transport boundary explicit.
// =============================================================================
`default_nettype none

module chip8_keypad_remote_core #(
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

  logic [15:0] raw_bitmap;
  logic [15:0] stable_bitmap;
  logic [15:0] previous_bitmap_q;
  logic [15:0] changed_bitmap;
  logic        remote_enable;
  logic        scan_enable;
  logic        irq_enable;
  logic        fifo_pop;
  logic [15:0] fifo_data;
  logic        fifo_empty;
  logic        fifo_full;
  logic        fifo_overflow;
  logic        event_valid;
  logic [15:0] event_payload;

  // ------------------------------------------------------------
  // Function declarations
  // ------------------------------------------------------------

  function automatic logic [3:0] first_set_index(input logic [15:0] value);
    logic [3:0] result;
    begin
      result = '0;
      for (int idx = '0; idx < 16; idx++) begin
        if (value[idx]) begin
          result = idx[3:0];
        end
      end
      first_set_index = result;
    end
  endfunction

  chip8_keypad_matrix_4x4 #(
    .CLK_HZ(CLK_HZ),
    .SCAN_HZ(SCAN_HZ),
    .ACTIVE_LOW(1'b1)
  ) u_matrix (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .enable_i(remote_enable && scan_enable),
    .rows_o(rows_o),
    .cols_i(cols_i),
    .key_bitmap_o(raw_bitmap),
    .scan_tick_o()
  );

  chip8_key_debounce u_debounce (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .keys_i(raw_bitmap),
    .keys_o(stable_bitmap)
  );

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign changed_bitmap = stable_bitmap ^ previous_bitmap_q;
  assign event_valid    = remote_enable && (changed_bitmap != 16'h0000);
  assign key_code_o     = first_set_index(changed_bitmap);
  assign key_bitmap_o   = stable_bitmap;
  assign key_valid_o    = |stable_bitmap;
  assign event_payload  = {6'h00, stable_bitmap[key_code_o],
    ~stable_bitmap[key_code_o], 4'h0, key_code_o};
  assign irq_event_o    = irq_enable && event_valid;
  assign irq_overflow_o = fifo_overflow;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : keypad_event_track_ff
    if (!rst_ni) begin
      previous_bitmap_q <= '0;
    end else if (event_valid) begin
      previous_bitmap_q <= stable_bitmap;
    end
  end

  chip8_keypad_dma u_key_dma (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .enable_i(remote_enable),
    .event_valid_i(event_valid),
    .event_data_i(event_payload),
    .pop_i(fifo_pop),
    .pop_data_o(fifo_data),
    .empty_o(fifo_empty),
    .full_o(fifo_full),
    .overflow_o(fifo_overflow),
    .done_irq_o(dma_done_o)
  );

  chip8_keypad_regs u_regs (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .key_bitmap_i(stable_bitmap),
    .key_valid_i(key_valid_o),
    .last_key_i(key_code_o),
    .fifo_empty_i(fifo_empty),
    .fifo_full_i(fifo_full),
    .overflow_i(fifo_overflow),
    .fifo_data_i(fifo_data),
    .fifo_pop_o(fifo_pop),
    .enable_o(remote_enable),
    .scan_enable_o(scan_enable),
    .irq_enable_o(irq_enable),
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
