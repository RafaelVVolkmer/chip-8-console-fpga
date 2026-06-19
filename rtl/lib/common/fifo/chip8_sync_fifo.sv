// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_sync_fifo.sv
// -----------------------------------------------------------------------------
// @brief Single-clock FIFO.
// =============================================================================
//
// Responsibilities:
// - Queue data inside one clock domain.
// - Expose ready/valid behavior clearly.
// - Keep occupancy and wrap logic local.
//
// Characteristics:
// - Synchronous storage primitive.
// - No CDC logic or asynchronous assumptions.
// - Useful for short buffering and packet staging.
//
// Design notes:
// - Keep depth and pointer wrap visible in the code.
// =============================================================================
`default_nettype none

module chip8_sync_fifo #(
  parameter int DATA_WIDTH = 8,
  parameter int DEPTH = 16,
  parameter int ADDR_WIDTH = $clog2(DEPTH)
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,
  input  logic                  push_valid_i,
  output logic                  push_ready_o,
  input  logic [DATA_WIDTH-1:0] push_data_i,
  output logic                  pop_valid_o,
  input  logic                  pop_ready_i,
  output logic [DATA_WIDTH-1:0] pop_data_o,
  output logic                  full_o,
  output logic                  empty_o,
  output logic                  overflow_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [DATA_WIDTH-1:0] mem_q [0:DEPTH-1];
  logic [ADDR_WIDTH:0] wr_ptr_q;
  logic [ADDR_WIDTH:0] wr_ptr_d;
  logic [ADDR_WIDTH:0] rd_ptr_q;
  logic [ADDR_WIDTH:0] rd_ptr_d;
  logic [ADDR_WIDTH:0] count_q;
  logic [ADDR_WIDTH:0] count_d;
  logic overflow_q;
  logic overflow_d;
  logic do_push;
  logic do_pop;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign full_o = count_q == DEPTH[ADDR_WIDTH:0];
  assign empty_o = count_q == '0;
  assign push_ready_o = !full_o;
  assign pop_valid_o = !empty_o;
  assign pop_data_o = mem_q[rd_ptr_q[ADDR_WIDTH-1:0]];
  assign overflow_o = overflow_q;
  assign do_push = push_valid_i && push_ready_o;
  assign do_pop = pop_ready_i && pop_valid_o;

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    wr_ptr_d = wr_ptr_q;
    rd_ptr_d = rd_ptr_q;
    count_d = count_q;
    overflow_d = overflow_q | (push_valid_i && !push_ready_o);

    if (do_push) begin
      wr_ptr_d = wr_ptr_q + {{ADDR_WIDTH{1'b0}}, 1'b1};
    end

    if (do_pop) begin
      rd_ptr_d = rd_ptr_q + {{ADDR_WIDTH{1'b0}}, 1'b1};
    end

    unique case ({do_push, do_pop})
      2'b10: count_d = count_q + {{ADDR_WIDTH{1'b0}}, 1'b1};
      2'b01: count_d = count_q - {{ADDR_WIDTH{1'b0}}, 1'b1};
      default: begin end
    endcase
  end

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      wr_ptr_q <= '0;
      rd_ptr_q <= '0;
      count_q <= '0;
      overflow_q <= '0;
    end else begin
      if (do_push) begin
        mem_q[wr_ptr_q[ADDR_WIDTH-1:0]] <= push_data_i;
      end

      wr_ptr_q <= wr_ptr_d;
      rd_ptr_q <= rd_ptr_d;
      count_q <= count_d;
      overflow_q <= overflow_d;
    end
  end

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      assert (count_q <= DEPTH[ADDR_WIDTH:0]);
      assert (full_o == (count_q == DEPTH[ADDR_WIDTH:0]));
      assert (empty_o == (count_q == '0));
      assert (wr_ptr_q - rd_ptr_q == count_q);

      if ($past(rst_ni) && $past(pop_valid_o && !pop_ready_i)) begin
        assert (pop_valid_o);
        assert (pop_data_o == $past(pop_data_o));
      end
    end
  end
`endif
endmodule

`default_nettype wire

// EOF
