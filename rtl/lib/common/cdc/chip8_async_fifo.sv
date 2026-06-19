// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_async_fifo.sv
// -----------------------------------------------------------------------------
// @brief Asynchronous FIFO with CDC pointers.
// =============================================================================
//
// Responsibilities:
// - Bridge clock domains with Gray-coded pointers.
// - Keep full and empty detection explicit.
// - Provide safe backpressure across asynchronous logic.
//
// Characteristics:
// - True CDC primitive.
// - Uses synchronizers and formal invariants.
// - Suitable for payloads crossing unrelated clocks.
//
// Design notes:
// - Keep pointer encoding and synchronization named.
// =============================================================================
`default_nettype none

module chip8_async_fifo #(
  parameter int DATA_WIDTH = 8,
  parameter int ADDR_WIDTH = 4
) (
  input  logic                  wr_clk_i,
  input  logic                  wr_rst_ni,
  input  logic                  wr_valid_i,
  output logic                  wr_ready_o,
  input  logic [DATA_WIDTH-1:0] wr_data_i,
  input  logic                  rd_clk_i,
  input  logic                  rd_rst_ni,
  output logic                  rd_valid_o,
  input  logic                  rd_ready_i,
  output logic [DATA_WIDTH-1:0] rd_data_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int DEPTH = 1 << ADDR_WIDTH;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
  logic [ADDR_WIDTH:0] wr_bin_q;
  logic [ADDR_WIDTH:0] wr_gray_q;
  logic [ADDR_WIDTH:0] rd_bin_q;
  logic [ADDR_WIDTH:0] rd_gray_q;
  logic [ADDR_WIDTH:0] rd_gray_wrclk;
  logic [ADDR_WIDTH:0] wr_gray_rdclk;
  logic [ADDR_WIDTH:0] wr_bin_d;
  logic [ADDR_WIDTH:0] rd_bin_d;
  logic [ADDR_WIDTH:0] wr_gray_d;
  logic [ADDR_WIDTH:0] rd_gray_d;
  logic full;
  logic empty;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign full = wr_gray_q == {~rd_gray_wrclk[ADDR_WIDTH:ADDR_WIDTH-1],
    rd_gray_wrclk[ADDR_WIDTH-2:0]};
  assign wr_bin_d = wr_bin_q + {{ADDR_WIDTH{1'b0}},
    (wr_valid_i && !full)};
  assign rd_bin_d = rd_bin_q + {{ADDR_WIDTH{1'b0}},
    (rd_ready_i && rd_valid_o)};
  assign wr_gray_d = (wr_bin_d >> 1) ^ wr_bin_d;
  assign rd_gray_d = (rd_bin_d >> 1) ^ rd_bin_d;
  assign empty = rd_gray_q == wr_gray_rdclk;
  assign wr_ready_o = !full;
  assign rd_valid_o = !empty;
  assign rd_data_o = mem[rd_bin_q[ADDR_WIDTH-1:0]];

  chip8_sync_2ff #(
    .WIDTH(ADDR_WIDTH + 1),
    .SYNC_RESET_LEVEL('0)
  ) u_rd_to_wr (
    .clk_i(wr_clk_i),
    .rst_ni(wr_rst_ni),
    .async_i(rd_gray_q),
    .sync_o(rd_gray_wrclk)
  );

  chip8_sync_2ff #(
    .WIDTH(ADDR_WIDTH + 1),
    .SYNC_RESET_LEVEL('0)
  ) u_wr_to_rd (
    .clk_i(rd_clk_i),
    .rst_ni(rd_rst_ni),
    .async_i(wr_gray_q),
    .sync_o(wr_gray_rdclk)
  );

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge wr_clk_i or negedge wr_rst_ni) begin
    if (!wr_rst_ni) begin
      wr_bin_q <= '0;
      wr_gray_q <= '0;
    end else begin
      if (wr_valid_i && wr_ready_o) begin
        mem[wr_bin_q[ADDR_WIDTH-1:0]] <= wr_data_i;
      end
      wr_bin_q <= wr_bin_d;
      wr_gray_q <= wr_gray_d;
    end
  end

  always_ff @(posedge rd_clk_i or negedge rd_rst_ni) begin
    if (!rd_rst_ni) begin
      rd_bin_q <= '0;
      rd_gray_q <= '0;
    end else begin
      rd_bin_q <= rd_bin_d;
      rd_gray_q <= rd_gray_d;
    end
  end

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_ff @(posedge wr_clk_i) begin
    if (wr_rst_ni && $past(wr_rst_ni)) begin
      assert ($onehot0(wr_gray_q ^ $past(wr_gray_q)));
    end
  end

  always_ff @(posedge rd_clk_i) begin
    if (rd_rst_ni && $past(rd_rst_ni)) begin
      assert ($onehot0(rd_gray_q ^ $past(rd_gray_q)));
      if ($past(rd_valid_o && !rd_ready_i)) begin
        assert (rd_valid_o);
        assert (rd_data_o == $past(rd_data_o));
      end
    end
  end
`endif
endmodule

`default_nettype wire

// EOF
