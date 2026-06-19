// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_dap_packet_parser.sv
// -----------------------------------------------------------------------------
// @brief DAP packet parser.
// =============================================================================
//
// Responsibilities:
// - Validate and unpack DAP request frames.
// - Expose command, length and payload fields cleanly.
// - Keep parser errors visible to the bridge.
//
// Characteristics:
// - Protocol parser with explicit state.
// - Consumes the UART byte stream.
// - Used by the USB debug transport.
//
// Design notes:
// - Keep frame fields and length checks named.
// =============================================================================
`default_nettype none

module chip8_dap_packet_parser (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        rx_valid_i,
  output logic        rx_ready_o,
  input  logic [7:0]  rx_data_i,
  output logic        cmd_valid_o,
  input  logic        cmd_ready_i,
  output logic [7:0]  cmd_seq_o,
  output logic [7:0]  cmd_code_o,
  output logic [7:0]  cmd_len_o,
  output logic [255:0] cmd_payload_o,
  output logic        error_o,
  output logic [7:0]  error_status_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [7:0] DAP_SOF = chip8_dap_pkg::DAP_SOF;
  localparam logic [7:0] DAP_VERSION = chip8_dap_pkg::DAP_VERSION;
  localparam logic [15:0] DAP_CRC_INIT = chip8_dap_pkg::DAP_CRC_INIT;
  localparam int DAP_MAX_PAYLOAD_BYTES =
    chip8_dap_pkg::DAP_MAX_PAYLOAD_BYTES;
  localparam logic [7:0] DAP_STATUS_OK = chip8_dap_pkg::DAP_STATUS_OK;
  localparam logic [7:0] DAP_STATUS_BAD_SOF =
    chip8_dap_pkg::DAP_STATUS_BAD_SOF;
  localparam logic [7:0] DAP_STATUS_BAD_VERSION =
    chip8_dap_pkg::DAP_STATUS_BAD_VERSION;
  localparam logic [7:0] DAP_STATUS_BAD_CRC =
    chip8_dap_pkg::DAP_STATUS_BAD_CRC;
  localparam logic [7:0] DAP_STATUS_BAD_LEN =
    chip8_dap_pkg::DAP_STATUS_BAD_LEN;
  // ------------------------------------------------------------
  // Type declarations
  // ------------------------------------------------------------

  // Byte-oriented DAP packet parser state machine.
  //
  // Responsibilities:
  // - Consume the fixed packet header in protocol order.
  // - Accumulate payload bytes and CRC before emitting a command.
  // - Convert malformed framing/version/length/CRC into DAP status codes.
  typedef enum logic [3:0] {
    CHIP8_DAP_PACKET_PARSER_STATE_SOF,
    CHIP8_DAP_PACKET_PARSER_STATE_VER,
    CHIP8_DAP_PACKET_PARSER_STATE_SEQ,
    CHIP8_DAP_PACKET_PARSER_STATE_CMD,
    CHIP8_DAP_PACKET_PARSER_STATE_LEN,
    CHIP8_DAP_PACKET_PARSER_STATE_PAYLOAD,
    CHIP8_DAP_PACKET_PARSER_STATE_CRC0,
    CHIP8_DAP_PACKET_PARSER_STATE_CRC1,
    CHIP8_DAP_PACKET_PARSER_STATE_EMIT
  } chip8_dap_packet_parser_state_e;

  chip8_dap_packet_parser_state_e state_q;
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [7:0] seq_q;
  logic [7:0] cmd_q;
  logic [7:0] len_q;
  logic [7:0] count_q;
  logic [255:0] payload_q;
  logic [15:0] crc_q;
  logic [15:0] crc_rx_q;
  logic [15:0] crc_d;
  logic crc_en;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign rx_ready_o = state_q != CHIP8_DAP_PACKET_PARSER_STATE_EMIT;
  assign cmd_valid_o =
    (state_q == CHIP8_DAP_PACKET_PARSER_STATE_EMIT) &&
    !error_o;
  assign cmd_seq_o = seq_q;
  assign cmd_code_o = cmd_q;
  assign cmd_len_o = len_q;
  assign cmd_payload_o = payload_q;

  chip8_crc16_ccitt u_crc (
    .crc_i(crc_q),
    .data_i(rx_data_i),
    .crc_o(crc_d)
  );

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    crc_en = '0;
    unique case (state_q)
      CHIP8_DAP_PACKET_PARSER_STATE_VER,
      CHIP8_DAP_PACKET_PARSER_STATE_SEQ,
      CHIP8_DAP_PACKET_PARSER_STATE_CMD,
      CHIP8_DAP_PACKET_PARSER_STATE_LEN,
      CHIP8_DAP_PACKET_PARSER_STATE_PAYLOAD: begin
        crc_en = rx_valid_i && rx_ready_o;
      end
      default: crc_en = '0;
    endcase
  end

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      state_q <= CHIP8_DAP_PACKET_PARSER_STATE_SOF;
      seq_q <= '0;
      cmd_q <= '0;
      len_q <= '0;
      count_q <= '0;
      payload_q <= '0;
      crc_q <= DAP_CRC_INIT;
      crc_rx_q <= '0;
      error_o <= '0;
      error_status_o <= DAP_STATUS_OK;
    end else begin
      if (crc_en) begin
        crc_q <= crc_d;
      end

      if ((state_q == CHIP8_DAP_PACKET_PARSER_STATE_EMIT) &&
          cmd_ready_i) begin
        state_q <= CHIP8_DAP_PACKET_PARSER_STATE_SOF;
        crc_q <= DAP_CRC_INIT;
        error_o <= '0;
        error_status_o <= DAP_STATUS_OK;
      end

      if (rx_valid_i && rx_ready_o) begin
        unique case (state_q)
          CHIP8_DAP_PACKET_PARSER_STATE_SOF: begin
            payload_q <= '0;
            crc_q <= DAP_CRC_INIT;
            error_o <= '0;
            error_status_o <= DAP_STATUS_OK;
            if (rx_data_i == DAP_SOF) begin
              state_q <= CHIP8_DAP_PACKET_PARSER_STATE_VER;
            end else begin
              error_o <= '1;
              error_status_o <= DAP_STATUS_BAD_SOF;
              state_q <= CHIP8_DAP_PACKET_PARSER_STATE_EMIT;
            end
          end

          CHIP8_DAP_PACKET_PARSER_STATE_VER: begin
            if (rx_data_i == DAP_VERSION) begin
              state_q <= CHIP8_DAP_PACKET_PARSER_STATE_SEQ;
            end else begin
              error_o <= '1;
              error_status_o <= DAP_STATUS_BAD_VERSION;
              state_q <= CHIP8_DAP_PACKET_PARSER_STATE_EMIT;
            end
          end

          CHIP8_DAP_PACKET_PARSER_STATE_SEQ: begin
            seq_q <= rx_data_i;
            state_q <= CHIP8_DAP_PACKET_PARSER_STATE_CMD;
          end

          CHIP8_DAP_PACKET_PARSER_STATE_CMD: begin
            cmd_q <= rx_data_i;
            state_q <= CHIP8_DAP_PACKET_PARSER_STATE_LEN;
          end

          CHIP8_DAP_PACKET_PARSER_STATE_LEN: begin
            len_q <= rx_data_i;
            count_q <= '0;
            if (rx_data_i > DAP_MAX_PAYLOAD_BYTES[7:0]) begin
              error_o <= '1;
              error_status_o <= DAP_STATUS_BAD_LEN;
              state_q <= CHIP8_DAP_PACKET_PARSER_STATE_EMIT;
            end else if (rx_data_i == 8'h00) begin
              state_q <= CHIP8_DAP_PACKET_PARSER_STATE_CRC0;
            end else begin
              state_q <= CHIP8_DAP_PACKET_PARSER_STATE_PAYLOAD;
            end
          end

          CHIP8_DAP_PACKET_PARSER_STATE_PAYLOAD: begin
            payload_q[(count_q << 3) +: 8] <= rx_data_i;
            if (count_q + 1'b1 == len_q) begin
              state_q <= CHIP8_DAP_PACKET_PARSER_STATE_CRC0;
            end
            count_q <= count_q + 1'b1;
          end

          CHIP8_DAP_PACKET_PARSER_STATE_CRC0: begin
            crc_rx_q[7:0] <= rx_data_i;
            state_q <= CHIP8_DAP_PACKET_PARSER_STATE_CRC1;
          end

          CHIP8_DAP_PACKET_PARSER_STATE_CRC1: begin
            crc_rx_q[15:8] <= rx_data_i;
            if ({rx_data_i, crc_rx_q[7:0]} != crc_q) begin
              error_o <= '1;
              error_status_o <= DAP_STATUS_BAD_CRC;
            end
            state_q <= CHIP8_DAP_PACKET_PARSER_STATE_EMIT;
          end

          default: state_q <= CHIP8_DAP_PACKET_PARSER_STATE_SOF;
        endcase
      end
    end
  end
endmodule

`default_nettype wire

// EOF
