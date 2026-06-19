// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_protocol_blocks_formal.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 protocol block suite.
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

module chip8_protocol_blocks_formal;
  (* gclk *) logic clk;
  // ------------------------------------------------------------
  // Testbench signals
  // ------------------------------------------------------------

  logic rst_n;
  logic past_valid;

  // ------------------------------------------------------------
  // Stimulus and checks
  // ------------------------------------------------------------

  initial begin
  rst_n = '0;
  past_valid = '0;
  end

  // ------------------------------------------------------------
  // Clocked testbench procedures
  // ------------------------------------------------------------

  always_ff @(posedge clk) begin
  past_valid <= '1;
  rst_n <= past_valid;
  end

  (* anyseq *) logic skid_in_valid;
  (* anyseq *) logic skid_out_ready;
  (* anyseq *) logic [7:0] skid_in_data;
  logic skid_in_ready;
  logic skid_out_valid;
  logic [7:0] skid_out_data;

  chip8_skid_buffer u_skid (
  .clk_i(clk),
  .rst_ni(rst_n),
  .in_valid_i(skid_in_valid),
  .in_ready_o(skid_in_ready),
  .in_data_i(skid_in_data),
  .out_valid_o(skid_out_valid),
  .out_ready_i(skid_out_ready),
  .out_data_o(skid_out_data)
  );

  (* anyseq *) logic fifo_push_valid;
  (* anyseq *) logic fifo_pop_ready;
  (* anyseq *) logic [7:0] fifo_push_data;
  logic fifo_push_ready;
  logic fifo_pop_valid;
  logic [7:0] fifo_pop_data;
  logic fifo_full;
  logic fifo_empty;
  logic fifo_overflow;

  chip8_sync_fifo #(
  .DATA_WIDTH(8),
  .DEPTH(4)
  ) u_sync_fifo (
  .clk_i(clk),
  .rst_ni(rst_n),
  .push_valid_i(fifo_push_valid),
  .push_ready_o(fifo_push_ready),
  .push_data_i(fifo_push_data),
  .pop_valid_o(fifo_pop_valid),
  .pop_ready_i(fifo_pop_ready),
  .pop_data_o(fifo_pop_data),
  .full_o(fifo_full),
  .empty_o(fifo_empty),
  .overflow_o(fifo_overflow)
  );

  logic async_wr_ready;
  logic async_rd_valid;
  logic [7:0] async_rd_data;

  chip8_async_fifo #(
  .DATA_WIDTH(8),
  .ADDR_WIDTH(2)
  ) u_async_fifo (
  .wr_clk_i(clk),
  .wr_rst_ni(rst_n),
  .wr_valid_i(fifo_push_valid),
  .wr_ready_o(async_wr_ready),
  .wr_data_i(fifo_push_data),
  .rd_clk_i(clk),
  .rd_rst_ni(rst_n),
  .rd_valid_o(async_rd_valid),
  .rd_ready_i(fifo_pop_ready),
  .rd_data_o(async_rd_data)
  );

  (* anyseq *) logic chunk_valid;
  (* anyseq *) logic [7:0] chunk_seq;
  (* anyseq *) logic [11:0] chunk_offset;
  (* anyseq *) logic [4:0] chunk_len;
  (* anyseq *) logic [127:0] chunk_data;
  (* anyseq *) logic [15:0] chunk_crc;
  (* anyseq *) logic rom_ready;
  logic chunk_ready;
  logic rom_valid;
  logic [11:0] rom_offset;
  logic [7:0] rom_data;
  logic writer_done;
  logic writer_bad_seq;
  logic writer_bad_crc;
  logic [7:0] writer_expected_seq;

  chip8_rom_chunk_writer u_writer (
  .clk_i(clk),
  .rst_ni(rst_n),
  .chunk_valid_i(chunk_valid),
  .chunk_ready_o(chunk_ready),
  .chunk_seq_i(chunk_seq),
  .chunk_offset_i(chunk_offset),
  .chunk_len_i(chunk_len),
  .chunk_data_i(chunk_data),
  .chunk_crc_i(chunk_crc),
  .rom_valid_o(rom_valid),
  .rom_ready_i(rom_ready),
  .rom_offset_o(rom_offset),
  .rom_data_o(rom_data),
  .done_o(writer_done),
  .bad_seq_o(writer_bad_seq),
  .bad_crc_o(writer_bad_crc),
  .expected_seq_o(writer_expected_seq)
  );

  always_ff @(posedge clk) begin
  if (past_valid && rst_n) begin
    assert (!(fifo_full && fifo_empty));
    assert (!(writer_bad_seq && writer_bad_crc));
    if (writer_done) begin
    assert (!rom_valid);
    end
  end
  end

  logic unused;
  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign unused = skid_in_ready ^ skid_out_valid ^ skid_out_data[0] ^
  fifo_push_ready ^ fifo_pop_valid ^ fifo_pop_data[0] ^
  fifo_overflow ^ async_wr_ready ^ async_rd_valid ^
  async_rd_data[0] ^ chunk_ready ^ rom_offset[0] ^ rom_data[0];
endmodule

`default_nettype wire

// EOF
