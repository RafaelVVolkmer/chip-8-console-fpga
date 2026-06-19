// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// tb_chip8_dap_protocol.sv
// -----------------------------------------------------------------------------
// @brief Debug bridge Tb chip8 dap protocol.
// =============================================================================
//
// Responsibilities:
// - Expose CPU and peripheral state without perturbing the core.
// - Bridge transport, packet parsing and response framing.
// - Keep debug policy separate from architectural state.
//
// Characteristics:
// - Debug transport or register helper.
// - Uses explicit packets, FIFOs and status state.
// - Shared by UART and DAP debug paths.
//
// Design notes:
// - Keep the packet grammar and status codes named.
// =============================================================================
`default_nettype none

module tb_chip8_dap_protocol;
  // ------------------------------------------------------------
  // Package imports
  // ------------------------------------------------------------

  import chip8_dap_pkg::*;

  // ------------------------------------------------------------
  // Testbench signals
  // ------------------------------------------------------------

  logic clk;
  logic rst_n;
  logic rx_valid;
  logic rx_ready;
  logic [7:0] rx_data;
  logic cmd_valid;
  logic cmd_ready;
  logic [7:0] cmd_seq;
  logic [7:0] cmd_code;
  logic [7:0] cmd_len;
  logic [255:0] cmd_payload;
  logic parser_error;
  logic [7:0] parser_status;

  logic chunk_valid;
  logic chunk_ready;
  logic [7:0] chunk_seq;
  logic [11:0] chunk_offset;
  logic [4:0] chunk_len;
  logic [127:0] chunk_data;
  logic [15:0] chunk_crc;
  logic rom_valid;
  logic rom_ready;
  logic [11:0] rom_offset;
  logic [7:0] rom_data;
  logic writer_done;
  logic writer_bad_seq;
  logic writer_bad_crc;
  logic [7:0] writer_expected_seq;

  // ------------------------------------------------------------
  // Stimulus and checks
  // ------------------------------------------------------------

  initial clk = '0;
  always #5 clk = ~clk;

  chip8_dap_packet_parser u_parser (
  .clk_i(clk),
  .rst_ni(rst_n),
  .rx_valid_i(rx_valid),
  .rx_ready_o(rx_ready),
  .rx_data_i(rx_data),
  .cmd_valid_o(cmd_valid),
  .cmd_ready_i(cmd_ready),
  .cmd_seq_o(cmd_seq),
  .cmd_code_o(cmd_code),
  .cmd_len_o(cmd_len),
  .cmd_payload_o(cmd_payload),
  .error_o(parser_error),
  .error_status_o(parser_status)
  );

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

  // ------------------------------------------------------------
  // Testbench tasks
  // ------------------------------------------------------------

  function automatic logic [15:0] crc16_step(
  input logic [15:0] crc_in,
  input logic [7:0] data
  );
  logic [15:0] crc;
  begin
    crc = crc_in ^ {data, 8'h00};
    for (int i = '0; i < 8; i++) begin
    if (crc[15]) begin
      crc = (crc << 1) ^ 16'h1021;
    end else begin
      crc = crc << 1;
    end
    end
    crc16_step = crc;
  end
  endfunction

  function automatic logic [15:0] crc4(
  input logic [7:0] b0,
  input logic [7:0] b1,
  input logic [7:0] b2,
  input logic [7:0] b3
  );
  logic [15:0] crc;
  begin
    crc = 16'hffff;
    crc = crc16_step(crc, b0);
    crc = crc16_step(crc, b1);
    crc = crc16_step(crc, b2);
    crc = crc16_step(crc, b3);
    crc4 = crc;
  end
  endfunction

  task automatic tick;
  @(posedge clk);
  #1;
  endtask

  task automatic send_byte(input logic [7:0] value);
  begin
    while (!rx_ready) begin
    tick();
    end
    rx_data = value;
    rx_valid = '1;
    tick();
    rx_valid = '0;
  end
  endtask

  task automatic send_packet(
  input logic [7:0] seq,
  input logic [7:0] cmd,
  input logic [7:0] len,
  input logic [31:0] payload,
  input logic corrupt_crc
  );
  logic [15:0] crc;
  begin
    crc = 16'hffff;
    crc = crc16_step(crc, DAP_VERSION);
    crc = crc16_step(crc, seq);
    crc = crc16_step(crc, cmd);
    crc = crc16_step(crc, len);
    for (int i = '0; i < len; i++) begin
    crc = crc16_step(crc, payload[i * 8 +: 8]);
    end
    if (corrupt_crc) begin
    crc = crc ^ 16'h0001;
    end

    send_byte(DAP_SOF);
    send_byte(DAP_VERSION);
    send_byte(seq);
    send_byte(cmd);
    send_byte(len);
    for (int i = '0; i < len; i++) begin
    send_byte(payload[i * 8 +: 8]);
    end
    send_byte(crc[7:0]);
    send_byte(crc[15:8]);
  end
  endtask

  initial begin : dap_protocol_test
  int unsigned timeout;

  rst_n = '0;
  rx_valid = '0;
  rx_data = '0;
  cmd_ready = '0;
  chunk_valid = '0;
  chunk_seq = '0;
  chunk_offset = '0;
  chunk_len = '0;
  chunk_data = '0;
  chunk_crc = '0;
  rom_ready = '1;
  repeat (4) tick();
  rst_n = '1;
  repeat (2) tick();

  $display("dap: good packet");
  send_packet(8'h34, DAP_CMD_ROM_PUSH, 8'd4, 32'h4433_2211, 1'b0);
  tick();
  assert (cmd_valid);
  assert (!parser_error);
  assert (cmd_seq == 8'h34);
  assert (cmd_code == DAP_CMD_ROM_PUSH);
  assert (cmd_len == 8'd4);
  assert (cmd_payload[31:0] == 32'h4433_2211);
  cmd_ready = '1;
  tick();
  cmd_ready = '0;

  $display("dap: bad crc packet");
  send_packet(8'h35, DAP_CMD_ROM_PUSH, 8'd4, 32'h8877_6655, 1'b1);
  tick();
  assert (parser_error);
  assert (parser_status == DAP_STATUS_BAD_CRC);
  cmd_ready = '1;
  tick();
  cmd_ready = '0;

  $display("dap: good chunk");
  chunk_seq = '0;
  chunk_offset = 12'h020;
  chunk_len = 5'd4;
  chunk_data[31:0] = 32'h4433_2211;
  chunk_crc = crc4(8'h11, 8'h22, 8'h33, 8'h44);
  chunk_valid = '1;
  tick();
  chunk_valid = '0;

  for (timeout = '0; timeout < 64 && !rom_valid; timeout++) begin
    tick();
  end
  assert (rom_valid);
  assert (rom_offset == 12'h020 && rom_data == 8'h11);
  tick();
  assert (rom_offset == 12'h021 && rom_data == 8'h22);
  tick();
  assert (rom_offset == 12'h022 && rom_data == 8'h33);
  tick();
  assert (rom_offset == 12'h023 && rom_data == 8'h44);
  tick();
  for (timeout = '0; timeout < 64 && !writer_done; timeout++) begin
    tick();
  end
  assert (writer_done);
  assert (!writer_bad_seq && !writer_bad_crc);
  assert (writer_expected_seq == 8'h01);
  tick();

  $display("dap: bad seq chunk");
  chunk_seq = '0;
  chunk_valid = '1;
  tick();
  chunk_valid = '0;
  for (timeout = '0; timeout < 64 && !writer_done; timeout++) begin
    tick();
  end
  assert (writer_done);
  assert (writer_bad_seq);

  $display("dap: protocol PASS");
  $finish;
  end

  initial begin : watchdog
  repeat (1000) tick();
  assert (0);
  $finish;
  end
endmodule

`default_nettype wire

// EOF
