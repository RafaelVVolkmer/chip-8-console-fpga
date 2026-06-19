// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// tb_chip8_keypad_remote_core.sv
// -----------------------------------------------------------------------------
// @brief SoC integration wrapper for Tb chip8 keypad remote core.
// =============================================================================
//
// Responsibilities:
// - Compose the CPU, memory, video, storage and debug blocks.
// - Route clocks, resets, buses and interrupts explicitly.
// - Keep integration policy outside leaf modules.
//
// Characteristics:
// - Top-level composition block.
// - Owns interconnect, not leaf algorithms.
// - Bridges board pins to reusable modules.
//
// Design notes:
// - Keep subsystem windows and clock domains named.
// =============================================================================
`default_nettype none

module tb_chip8_keypad_remote_core;
  // ------------------------------------------------------------
  // Testbench signals
  // ------------------------------------------------------------

  logic clk;
  logic rst_n;
  logic [3:0] rows;
  logic [3:0] cols;
  logic [15:0] key_bitmap;
  logic key_valid;
  logic [3:0] key_code;
  logic irq_event;
  logic irq_overflow;
  logic dma_done;
  logic [31:0] rdata;
  logic ready;

  // ------------------------------------------------------------
  // Stimulus and checks
  // ------------------------------------------------------------

  initial clk = '0;
  always #5 clk = ~clk;

  chip8_keypad_remote_core #(
  .CLK_HZ(1_000),
  .SCAN_HZ(10)
  ) u_dut (
  .clk_i(clk),
  .rst_ni(rst_n),
  .rows_o(rows),
  .cols_i(cols),
  .key_bitmap_o(key_bitmap),
  .key_valid_o(key_valid),
  .key_code_o(key_code),
  .irq_event_o(irq_event),
  .irq_overflow_o(irq_overflow),
  .dma_done_o(dma_done),
  .reg_valid_i(1'b1),
  .reg_we_i(1'b0),
  .reg_addr_i(8'h08),
  .reg_wdata_i(32'h0),
  .reg_wstrb_i(4'h0),
  .reg_ready_o(ready),
  .reg_rdata_o(rdata)
  );

  // ------------------------------------------------------------
  // Testbench tasks
  // ------------------------------------------------------------

  task automatic tick;
  @(posedge clk);
  #1;
  endtask

  initial begin : keypad_remote_smoke
  rst_n = '0;
  cols = 4'b1111;
  repeat (3) tick();
  rst_n = '1;
  repeat (20) begin
    if (rows[0] == 1'b0) begin
    cols = 4'b1110;
    end else begin
    cols = 4'b1111;
    end
    tick();
    assert (key_code <= 4'hf);
  end
  assert (ready);
  assert (rdata[31:16] == 16'h0000);
  assert (!irq_overflow);
  $finish;
  end
endmodule

`default_nettype wire

// EOF
