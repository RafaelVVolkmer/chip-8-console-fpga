// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_stack.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 call stack.
// =============================================================================
//
// Responsibilities:
// - Store return addresses for subroutine calls.
// - Manage push and pop behavior explicitly.
// - Expose overflow and underflow semantics clearly.
//
// Characteristics:
// - Fixed-depth architectural stack.
// - Synchronous updates with simple control.
// - Used only by call/return opcodes.
//
// Design notes:
// - Make stack depth and wrap behavior explicit.
// =============================================================================
`default_nettype none

module chip8_stack (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        push_we_i,
  input  logic        pop_we_i,
  input  logic [11:0] push_data_i,
  output logic [11:0] pop_data_o,
  output logic        overflow_o,
  output logic        underflow_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int unsigned CHIP8_STACK_DEPTH = 16;
  localparam int unsigned CHIP8_STACK_ADDR_WIDTH = 4;
  localparam int unsigned CHIP8_STACK_DEPTH_WIDTH = 5;
  localparam int unsigned CHIP8_STACK_ENTRY_WIDTH = 12;
  localparam int unsigned CHIP8_STACK_BITS =
    CHIP8_STACK_DEPTH * CHIP8_STACK_ENTRY_WIDTH;

  localparam logic [CHIP8_STACK_DEPTH_WIDTH-1:0] CHIP8_STACK_FULL_DEPTH =
    CHIP8_STACK_DEPTH_WIDTH'(CHIP8_STACK_DEPTH);

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [CHIP8_STACK_BITS-1:0] stack_flat_q;
  logic [CHIP8_STACK_BITS-1:0] stack_flat_d;
  logic [CHIP8_STACK_ADDR_WIDTH-1:0] sp_q;
  logic [CHIP8_STACK_ADDR_WIDTH-1:0] sp_d;
  logic [CHIP8_STACK_DEPTH_WIDTH-1:0] depth_q;
  logic [CHIP8_STACK_DEPTH_WIDTH-1:0] depth_d;
  logic overflow_q;
  logic overflow_d;
  logic underflow_q;
  logic underflow_d;
  logic [3:0] pop_addr;
  logic [7:0] push_bit_base;
  logic [7:0] pop_bit_base;
  logic [3:0] sp_delta;
  logic [CHIP8_STACK_BITS-1:0] push_mask;
  logic [CHIP8_STACK_BITS-1:0] push_data_flat;
  logic push_accept;
  logic pop_accept;
  logic push_full;
  logic pop_empty;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign pop_addr = (sp_q - 1'b1) & 4'hf;
  assign push_bit_base = ({4'h0, sp_q} << 3) + ({4'h0, sp_q} << 2);
  assign pop_bit_base = ({4'h0, pop_addr} << 3) + ({4'h0, pop_addr} << 2);
  assign push_full = depth_q == CHIP8_STACK_FULL_DEPTH;
  assign pop_empty = depth_q == '0;
  assign push_accept = push_we_i & !(push_full & !pop_we_i);
  assign pop_accept = pop_we_i & !push_we_i & !pop_empty;
  assign sp_delta = {3'h0, push_accept} - {3'h0, pop_accept};
  assign push_mask = ({{(CHIP8_STACK_BITS-CHIP8_STACK_ENTRY_WIDTH){1'b0}},
    {CHIP8_STACK_ENTRY_WIDTH{1'b1}}} << push_bit_base) &
    {CHIP8_STACK_BITS{push_accept}};
  assign push_data_flat = {{(CHIP8_STACK_BITS-CHIP8_STACK_ENTRY_WIDTH){1'b0}},
    push_data_i} << push_bit_base;
  assign pop_data_o = stack_flat_q[pop_bit_base +: CHIP8_STACK_ENTRY_WIDTH];
  assign overflow_o = overflow_q;
  assign underflow_o = underflow_q;

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    stack_flat_d = (stack_flat_q & ~push_mask) | (push_data_flat &
      push_mask);
    sp_d = sp_q + sp_delta;
    depth_d = depth_q;
    overflow_d = push_we_i & push_full & !pop_we_i;
    underflow_d = pop_we_i & !push_we_i & pop_empty;

    if (push_accept && !pop_we_i &&
        depth_q != CHIP8_STACK_FULL_DEPTH) begin
      depth_d = depth_q + 1'b1;
    end else if (pop_accept && depth_q != '0) begin
      depth_d = depth_q - 1'b1;
    end
  end

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      stack_flat_q <= '0;
      sp_q <= '0;
      depth_q <= '0;
      overflow_q <= '0;
      underflow_q <= '0;
    end else begin
      stack_flat_q <= stack_flat_d;
      sp_q <= sp_d;
      depth_q <= depth_d;
      overflow_q <= overflow_d;
      underflow_q <= underflow_d;
    end
  end

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  logic formal_past_valid_q = 1'b0;

  always_ff @(posedge clk_i) begin
    formal_past_valid_q <= 1'b1;

    if (formal_past_valid_q && rst_ni) begin
      assert (depth_q <= CHIP8_STACK_FULL_DEPTH);
    end
  end
`endif
endmodule

`default_nettype wire

// EOF
