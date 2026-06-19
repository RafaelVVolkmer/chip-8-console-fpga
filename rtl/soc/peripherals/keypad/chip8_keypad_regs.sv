// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_keypad_regs.sv
// -----------------------------------------------------------------------------
// @brief Keypad register block.
// =============================================================================
//
// Responsibilities:
// - Expose keypad control, status and FIFO registers.
// - Let software read the bitmap and last key state.
// - Keep pop and enable behavior explicit.
//
// Characteristics:
// - Synchronous register interface.
// - No scanning logic beyond register-visible state.
// - Used by the keypad accelerator and SoC bus.
//
// Design notes:
// - Keep control bits and FIFO offsets named.
// =============================================================================
`default_nettype none

module chip8_keypad_regs (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic [15:0] key_bitmap_i,
  input  logic        key_valid_i,
  input  logic [3:0]  last_key_i,
  input  logic        fifo_empty_i,
  input  logic        fifo_full_i,
  input  logic        overflow_i,
  input  logic [15:0] fifo_data_i,
  output logic        fifo_pop_o,
  output logic        enable_o,
  output logic        scan_enable_o,
  output logic        irq_enable_o,

  input  logic        reg_valid_i,
  input  logic        reg_we_i,
  input  logic [7:0]  reg_addr_i,
  input  logic [31:0] reg_wdata_i,
  input  logic [3:0]  reg_wstrb_i,
  output logic        reg_ready_o,
  output logic [31:0] reg_rdata_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [7:0] KEYPAD_CTRL_OFFSET = 8'h00;
  localparam logic [7:0] KEYPAD_STATUS_OFFSET = 8'h04;
  localparam logic [7:0] KEYPAD_BITMAP_OFFSET = 8'h08;
  localparam logic [7:0] KEYPAD_LAST_KEY_OFFSET = 8'h0c;
  localparam logic [7:0] KEYPAD_FIFO_OFFSET = 8'h10;

  localparam int unsigned KEYPAD_CTRL_ENABLE_BIT = 0;
  localparam int unsigned KEYPAD_CTRL_SCAN_ENABLE_BIT = 1;
  localparam int unsigned KEYPAD_CTRL_IRQ_ENABLE_BIT = 2;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic ctrl_enable_q;
  logic scan_enable_q;
  logic irq_enable_q;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign enable_o      = ctrl_enable_q;
  assign scan_enable_o = scan_enable_q;
  assign irq_enable_o  = irq_enable_q;
  assign reg_ready_o   = reg_valid_i;
  assign fifo_pop_o =
    reg_valid_i && !reg_we_i && reg_addr_i == KEYPAD_FIFO_OFFSET &&
    !fifo_empty_i;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : keypad_regs_control_ff
    if (!rst_ni) begin
      ctrl_enable_q <= '1;
      scan_enable_q <= '1;
      irq_enable_q  <= '1;
    end else if (
        reg_valid_i && reg_we_i && reg_addr_i == KEYPAD_CTRL_OFFSET &&
        reg_wstrb_i[0]
    ) begin
      ctrl_enable_q <= reg_wdata_i[KEYPAD_CTRL_ENABLE_BIT];
      scan_enable_q <= reg_wdata_i[KEYPAD_CTRL_SCAN_ENABLE_BIT];
      irq_enable_q  <= reg_wdata_i[KEYPAD_CTRL_IRQ_ENABLE_BIT];
    end
  end

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin : keypad_regs_read_comb
    unique case (reg_addr_i)
      KEYPAD_CTRL_OFFSET: reg_rdata_o = {29'h0, irq_enable_q, scan_enable_q,
        ctrl_enable_q};
      KEYPAD_STATUS_OFFSET: reg_rdata_o = {26'h0, overflow_i, fifo_full_i,
        fifo_empty_i, key_valid_i, 1'b0, 1'b0};
      KEYPAD_BITMAP_OFFSET: reg_rdata_o = {16'h0000, key_bitmap_i};
      KEYPAD_LAST_KEY_OFFSET: reg_rdata_o = {28'h0, last_key_i};
      KEYPAD_FIFO_OFFSET: begin
        reg_rdata_o = {16'h0000, fifo_data_i};
      end
      default: reg_rdata_o = '0;
    endcase
  end
endmodule

`default_nettype wire

// EOF
