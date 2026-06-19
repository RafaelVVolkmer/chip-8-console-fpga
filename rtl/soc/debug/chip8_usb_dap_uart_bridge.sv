// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_usb_dap_uart_bridge.sv
// -----------------------------------------------------------------------------
// @brief USB DAP to UART bridge.
// =============================================================================
//
// Responsibilities:
// - Translate DAP packets into UART transport and back.
// - Bridge command, status and ROM-write flows.
// - Keep CRC, lock and sequencing behavior explicit.
//
// Characteristics:
// - Protocol bridge with packet parsing and response framing.
// - Owns only transport and command-state logic.
// - Used by the USB-facing debug path.
//
// Design notes:
// - Keep the DAP framing and CRC contract named.
// =============================================================================
`default_nettype none

module chip8_usb_dap_uart_bridge #(
  parameter int CLK_HZ = 27_000_000,
  parameter int BAUD = 115200,
  parameter int COMMAND_TIMEOUT_CYCLES = 1_000_000,
  parameter logic [31:0] UNLOCK_KEY = 32'hC8DA_9F0D
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  input  logic        uart_rx_i,
  output logic        uart_tx_o,

  output logic        core_hold_o,
  output logic        core_release_override_o,
  output logic        rom_load_valid_o,
  output logic [11:0] rom_load_offset_o,
  output logic [7:0]  rom_load_data_o,

  output logic [15:0] m_axi_awaddr_o,
  output logic        m_axi_awvalid_o,
  input  logic        m_axi_awready_i,
  output logic [31:0] m_axi_wdata_o,
  output logic [3:0]  m_axi_wstrb_o,
  output logic        m_axi_wvalid_o,
  input  logic        m_axi_wready_i,
  input  logic [1:0]  m_axi_bresp_i,
  input  logic        m_axi_bvalid_i,
  output logic        m_axi_bready_o,
  output logic [15:0] m_axi_araddr_o,
  output logic        m_axi_arvalid_o,
  input  logic        m_axi_arready_i,
  input  logic [31:0] m_axi_rdata_i,
  input  logic [1:0]  m_axi_rresp_i,
  input  logic        m_axi_rvalid_i,
  output logic        m_axi_rready_o,

  output logic        busy_o,
  output logic        error_o,
  output logic        locked_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [7:0] DAP_SOF = chip8_dap_pkg::DAP_SOF;
  localparam logic [7:0] DAP_VERSION = chip8_dap_pkg::DAP_VERSION;
  localparam logic [15:0] DAP_CRC_INIT = chip8_dap_pkg::DAP_CRC_INIT;
  localparam int DAP_MAX_PAYLOAD_BYTES =
    chip8_dap_pkg::DAP_MAX_PAYLOAD_BYTES;
  localparam logic [7:0] DAP_CMD_PING = chip8_dap_pkg::DAP_CMD_PING;
  localparam logic [7:0] DAP_CMD_ID = chip8_dap_pkg::DAP_CMD_ID;
  localparam logic [7:0] DAP_CMD_UNLOCK = chip8_dap_pkg::DAP_CMD_UNLOCK;
  localparam logic [7:0] DAP_CMD_LOCK = chip8_dap_pkg::DAP_CMD_LOCK;
  localparam logic [7:0] DAP_CMD_HOLD_CORE =
    chip8_dap_pkg::DAP_CMD_HOLD_CORE;
  localparam logic [7:0] DAP_CMD_READ32 = chip8_dap_pkg::DAP_CMD_READ32;
  localparam logic [7:0] DAP_CMD_WRITE32 = chip8_dap_pkg::DAP_CMD_WRITE32;
  localparam logic [7:0] DAP_CMD_ROM_WRITE =
    chip8_dap_pkg::DAP_CMD_ROM_WRITE;
  localparam logic [7:0] DAP_CMD_GET_STATUS =
    chip8_dap_pkg::DAP_CMD_GET_STATUS;
  localparam logic [7:0] DAP_STATUS_OK = chip8_dap_pkg::DAP_STATUS_OK;
  localparam logic [7:0] DAP_STATUS_BAD_CMD =
    chip8_dap_pkg::DAP_STATUS_BAD_CMD;
  localparam logic [7:0] DAP_STATUS_BAD_LEN =
    chip8_dap_pkg::DAP_STATUS_BAD_LEN;
  localparam logic [7:0] DAP_STATUS_LOCKED =
    chip8_dap_pkg::DAP_STATUS_LOCKED;
  localparam logic [7:0] DAP_STATUS_BUS_ERROR =
    chip8_dap_pkg::DAP_STATUS_BUS_ERROR;
  localparam logic [7:0] DAP_STATUS_BUSY = chip8_dap_pkg::DAP_STATUS_BUSY;
  localparam logic [7:0] DAP_STATUS_BAD_SEQ =
    chip8_dap_pkg::DAP_STATUS_BAD_SEQ;
  localparam logic [7:0] DAP_STATUS_ROM_CRC =
    chip8_dap_pkg::DAP_STATUS_ROM_CRC;
  localparam int unsigned BAUD_DIV_RAW = CLK_HZ / BAUD;
  localparam int unsigned BAUD_DIV = (BAUD_DIV_RAW < 1) ? 1 : BAUD_DIV_RAW;
  localparam int unsigned BAUD_HALF_DIV = BAUD_DIV >> 1;
  localparam int unsigned RESP_MAX_BYTES = 40;
  localparam int unsigned DAP_CRC_DATA_BITS = 8;
  localparam logic [7:0] DAP_CRC_INPUT_PAD = 8'h00;
  localparam logic [15:0] DAP_CRC_POLY = 16'h1021;

  // ------------------------------------------------------------
  // Type declarations
  // ------------------------------------------------------------

  // UART bit-level state shared by RX and TX sides of the DAP bridge.
  //
  // Responsibilities:
  // - Track the serial framing phase for one byte.
  // - Keep bridge byte timing independent from command-engine state.
  typedef enum logic [1:0] {
    UART_IDLE,
    UART_START,
    UART_DATA,
    UART_STOP
  } uart_state_t;

  // DAP command engine state.
  //
  // Responsibilities:
  // - Dispatch parsed DAP commands to AXI, ROM-load or control paths.
  // - Hold busy/error responses until a host-visible response is serialized.
  // - Enforce lock and sequencing behavior around ROM writes.
  typedef enum logic [2:0] {
    ENG_IDLE,
    ENG_AXI_WRITE,
    ENG_AXI_READ,
    ENG_ROM_WAIT,
    ENG_RESP,
    ENG_ERROR
  } engine_state_t;

  uart_state_t rx_state_q;
  uart_state_t tx_state_q;
  engine_state_t engine_state_q;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [31:0] rx_div_q;
  logic [31:0] tx_div_q;
  logic [2:0]  rx_bit_q;
  logic [2:0]  tx_bit_q;
  logic [7:0]  rx_shift_q;
  logic [7:0]  tx_shift_q;
  logic        rx_sync0_q;
  logic        rx_sync1_q;
  logic        rx_valid_q;
  logic [7:0]  rx_data_q;
  logic        tx_busy;
  logic        tx_start;
  logic [7:0]  tx_start_data;

  logic        rx_fifo_pop_valid;
  logic        rx_fifo_pop_ready;
  logic [7:0]  rx_fifo_pop_data;
  logic        rx_fifo_full;
  logic        rx_fifo_empty;
  logic        rx_fifo_overflow;

  logic        tx_fifo_push_valid;
  logic        tx_fifo_push_ready;
  logic [7:0]  tx_fifo_push_data;
  logic        tx_fifo_pop_valid;
  logic        tx_fifo_pop_ready;
  logic [7:0]  tx_fifo_pop_data;
  logic        tx_fifo_full;
  logic        tx_fifo_empty;
  logic        tx_fifo_overflow;

  logic        cmd_valid;
  logic        cmd_ready;
  logic [7:0]  cmd_seq;
  logic [7:0]  cmd_code;
  logic [7:0]  cmd_len;
  logic [255:0] cmd_payload;
  logic        parser_error;
  logic [7:0]  parser_error_status;
  logic        cmd_event;

  logic        unlocked_q;
  logic [7:0]  active_seq_q;
  logic [7:0]  active_status_q;
  logic [255:0] resp_payload_q;
  logic [15:0] resp_crc_q;
  logic [7:0]  resp_len_q;
  logic [8:0]  resp_total_q;
  logic [8:0]  resp_idx_q;
  logic [7:0]  resp_payload_bit_idx;
  logic        resp_active_q;
  logic [31:0] timeout_q;

  logic        chunk_valid_q;
  logic        chunk_ready;
  logic        chunk_done;
  logic        chunk_bad_seq;
  logic        chunk_bad_crc;
  logic [7:0]  chunk_expected_seq;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign locked_o = !unlocked_q;
  assign tx_busy = tx_state_q != UART_IDLE;
  assign tx_start = tx_fifo_pop_valid && !tx_busy;
  assign tx_start_data = tx_fifo_pop_data;
  assign tx_fifo_pop_ready = tx_start;
  assign cmd_event = (cmd_valid || parser_error) &&
    (engine_state_q == ENG_IDLE) && !resp_active_q;
  assign cmd_ready = cmd_event;
  assign busy_o = (engine_state_q != ENG_IDLE) || resp_active_q || tx_busy ||
    m_axi_awvalid_o || m_axi_wvalid_o || m_axi_arvalid_o ||
    m_axi_bready_o || m_axi_rready_o;
  assign tx_fifo_push_valid = resp_active_q;
  assign resp_payload_bit_idx = 8'(resp_idx_q - 9'd5) << 3;
  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin : response_byte_comb
    unique case (resp_idx_q)
      9'd0: tx_fifo_push_data = DAP_SOF;
      9'd1: tx_fifo_push_data = DAP_VERSION;
      9'd2: tx_fifo_push_data = active_seq_q;
      9'd3: tx_fifo_push_data = active_status_q;
      9'd4: tx_fifo_push_data = resp_len_q;
      default: begin
        if (resp_idx_q < ({1'b0, resp_len_q} + 9'd5)) begin
          tx_fifo_push_data =
            resp_payload_q[resp_payload_bit_idx +: 8];
        end else if (resp_idx_q == ({1'b0, resp_len_q} + 9'd5)) begin
          tx_fifo_push_data = resp_crc_q[7:0];
        end else begin
          tx_fifo_push_data = resp_crc_q[15:8];
        end
      end
    endcase
  end

  // ------------------------------------------------------------
  // Function declarations
  // ------------------------------------------------------------

  function automatic logic [15:0] crc16_update(
    input logic [15:0] crc_in,
    input logic [7:0] data
  );
    logic [15:0] crc;
    begin
      crc = crc_in ^ {data, DAP_CRC_INPUT_PAD};
      for (int bit_idx = '0; bit_idx < DAP_CRC_DATA_BITS; bit_idx++) begin
        crc = crc[15] ? ((crc << 1) ^ DAP_CRC_POLY) : (crc << 1);
      end
      crc16_update = crc;
    end
  endfunction

  task automatic start_response(
    input logic [7:0] seq,
    input logic [7:0] status,
    input logic [7:0] len,
    input logic [255:0] payload
  );
    logic [15:0] crc;
    begin
      crc = DAP_CRC_INIT;
      crc = crc16_update(crc, DAP_VERSION);
      crc = crc16_update(crc, seq);
      crc = crc16_update(crc, status);
      crc = crc16_update(crc, len);
      for (int idx = '0; idx < DAP_MAX_PAYLOAD_BYTES; idx++) begin
        if (idx < len) begin
          crc = crc16_update(crc, payload[(idx << 3) +: 8]);
        end
      end
      active_seq_q <= seq;
      active_status_q <= status;
      resp_len_q <= len;
      resp_payload_q <= payload;
      resp_crc_q <= crc;
      resp_total_q <= {1'b0, len} + 9'd7;
      resp_idx_q <= '0;
      resp_active_q <= '1;
    end
  endtask

  chip8_sync_fifo #(.DATA_WIDTH(8), .DEPTH(32)) u_rx_fifo (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .push_valid_i(rx_valid_q),
    .push_ready_o(),
    .push_data_i(rx_data_q),
    .pop_valid_o(rx_fifo_pop_valid),
    .pop_ready_i(rx_fifo_pop_ready),
    .pop_data_o(rx_fifo_pop_data),
    .full_o(rx_fifo_full),
    .empty_o(rx_fifo_empty),
    .overflow_o(rx_fifo_overflow)
  );

  chip8_sync_fifo #(.DATA_WIDTH(8), .DEPTH(64)) u_tx_fifo (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .push_valid_i(tx_fifo_push_valid),
    .push_ready_o(tx_fifo_push_ready),
    .push_data_i(tx_fifo_push_data),
    .pop_valid_o(tx_fifo_pop_valid),
    .pop_ready_i(tx_fifo_pop_ready),
    .pop_data_o(tx_fifo_pop_data),
    .full_o(tx_fifo_full),
    .empty_o(tx_fifo_empty),
    .overflow_o(tx_fifo_overflow)
  );

  chip8_dap_packet_parser u_packet_parser (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .rx_valid_i(rx_fifo_pop_valid),
    .rx_ready_o(rx_fifo_pop_ready),
    .rx_data_i(rx_fifo_pop_data),
    .cmd_valid_o(cmd_valid),
    .cmd_ready_i(cmd_ready),
    .cmd_seq_o(cmd_seq),
    .cmd_code_o(cmd_code),
    .cmd_len_o(cmd_len),
    .cmd_payload_o(cmd_payload),
    .error_o(parser_error),
    .error_status_o(parser_error_status)
  );

  chip8_rom_chunk_writer u_rom_chunk_writer (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .chunk_valid_i(chunk_valid_q),
    .chunk_ready_o(chunk_ready),
    .chunk_seq_i(cmd_seq),
    .chunk_offset_i(cmd_payload[11:0]),
    .chunk_len_i(cmd_payload[20:16]),
    .chunk_data_i(cmd_payload[167:40]),
    .chunk_crc_i(cmd_payload[39:24]),
    .rom_valid_o(rom_load_valid_o),
    .rom_ready_i(1'b1),
    .rom_offset_o(rom_load_offset_o),
    .rom_data_o(rom_load_data_o),
    .done_o(chunk_done),
    .bad_seq_o(chunk_bad_seq),
    .bad_crc_o(chunk_bad_crc),
    .expected_seq_o(chunk_expected_seq)
  );

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : uart_rx_ff
    if (!rst_ni) begin
      rx_state_q <= UART_IDLE;
      rx_div_q <= '0;
      rx_bit_q <= '0;
      rx_shift_q <= '0;
      rx_data_q <= '0;
      rx_valid_q <= '0;
      rx_sync0_q <= '1;
      rx_sync1_q <= '1;
    end else begin
      rx_valid_q <= '0;
      rx_sync0_q <= uart_rx_i;
      rx_sync1_q <= rx_sync0_q;
      unique case (rx_state_q)
        UART_IDLE: begin
          rx_div_q <= '0;
          rx_bit_q <= '0;
          if (!rx_sync1_q) rx_state_q <= UART_START;
        end
        UART_START: begin
          if (rx_div_q == BAUD_HALF_DIV) begin
            rx_div_q <= '0;
            rx_state_q <= rx_sync1_q ? UART_IDLE : UART_DATA;
          end else begin
            rx_div_q <= rx_div_q + 1'b1;
          end
        end
        UART_DATA: begin
          if (rx_div_q == BAUD_DIV - 1) begin
            rx_div_q <= '0;
            rx_shift_q <= {rx_sync1_q, rx_shift_q[7:1]};
            if (rx_bit_q == 3'd7) begin
              rx_bit_q <= '0;
              rx_state_q <= UART_STOP;
            end else begin
              rx_bit_q <= rx_bit_q + 1'b1;
            end
          end else begin
            rx_div_q <= rx_div_q + 1'b1;
          end
        end
        UART_STOP: begin
          if (rx_div_q == BAUD_DIV - 1) begin
            rx_div_q <= '0;
            rx_data_q <= rx_shift_q;
            rx_valid_q <= '1;
            rx_state_q <= UART_IDLE;
          end else begin
            rx_div_q <= rx_div_q + 1'b1;
          end
        end
        default: rx_state_q <= UART_IDLE;
      endcase
    end
  end

  always_ff @(posedge clk_i) begin : uart_tx_ff
    if (!rst_ni) begin
      tx_state_q <= UART_IDLE;
      tx_div_q <= '0;
      tx_bit_q <= '0;
      tx_shift_q <= '0;
      uart_tx_o <= '1;
    end else begin
      unique case (tx_state_q)
        UART_IDLE: begin
          uart_tx_o <= '1;
          tx_div_q <= '0;
          tx_bit_q <= '0;
          if (tx_start) begin
            tx_shift_q <= tx_start_data;
            tx_state_q <= UART_START;
          end
        end
        UART_START: begin
          uart_tx_o <= '0;
          if (tx_div_q == BAUD_DIV - 1) begin
            tx_div_q <= '0;
            tx_state_q <= UART_DATA;
          end else begin
            tx_div_q <= tx_div_q + 1'b1;
          end
        end
        UART_DATA: begin
          uart_tx_o <= tx_shift_q[0];
          if (tx_div_q == BAUD_DIV - 1) begin
            tx_div_q <= '0;
            tx_shift_q <= {1'b0, tx_shift_q[7:1]};
            if (tx_bit_q == 3'd7) begin
              tx_bit_q <= '0;
              tx_state_q <= UART_STOP;
            end else begin
              tx_bit_q <= tx_bit_q + 1'b1;
            end
          end else begin
            tx_div_q <= tx_div_q + 1'b1;
          end
        end
        UART_STOP: begin
          uart_tx_o <= '1;
          if (tx_div_q == BAUD_DIV - 1) begin
            tx_div_q <= '0;
            tx_state_q <= UART_IDLE;
          end else begin
            tx_div_q <= tx_div_q + 1'b1;
          end
        end
        default: tx_state_q <= UART_IDLE;
      endcase
    end
  end

  always_ff @(posedge clk_i) begin : engine_ff
    if (!rst_ni) begin
      engine_state_q <= ENG_IDLE;
      unlocked_q <= '0;
      active_seq_q <= '0;
      active_status_q <= DAP_STATUS_OK;
      resp_payload_q <= '0;
      resp_crc_q <= DAP_CRC_INIT;
      resp_len_q <= '0;
      resp_total_q <= '0;
      resp_idx_q <= '0;
      resp_active_q <= '0;
      timeout_q <= '0;
      chunk_valid_q <= '0;
      core_hold_o <= '0;
      core_release_override_o <= '0;
      m_axi_awaddr_o <= '0;
      m_axi_awvalid_o <= '0;
      m_axi_wdata_o <= '0;
      m_axi_wstrb_o <= '0;
      m_axi_wvalid_o <= '0;
      m_axi_bready_o <= '0;
      m_axi_araddr_o <= '0;
      m_axi_arvalid_o <= '0;
      m_axi_rready_o <= '0;
      error_o <= '0;
    end else begin
      chunk_valid_q <= '0;
      core_release_override_o <= '0;

      if (resp_active_q && tx_fifo_push_ready) begin
        if (resp_idx_q + 1'b1 >= resp_total_q) begin
          resp_idx_q <= '0;
          resp_active_q <= '0;
        end else begin
          resp_idx_q <= resp_idx_q + 1'b1;
        end
      end

      if (m_axi_awvalid_o && m_axi_awready_i) m_axi_awvalid_o <= '0;
      if (m_axi_wvalid_o && m_axi_wready_i) m_axi_wvalid_o <= '0;
      if (m_axi_arvalid_o && m_axi_arready_i) m_axi_arvalid_o <= '0;

      if (engine_state_q == ENG_IDLE || cmd_event) begin
        timeout_q <= '0;
      end else if (timeout_q < COMMAND_TIMEOUT_CYCLES) begin
        timeout_q <= timeout_q + 1'b1;
      end

      if (timeout_q == COMMAND_TIMEOUT_CYCLES) begin
        m_axi_awvalid_o <= '0;
        m_axi_wvalid_o <= '0;
        m_axi_arvalid_o <= '0;
        m_axi_bready_o <= '0;
        m_axi_rready_o <= '0;
        error_o <= '1;
        start_response(active_seq_q, DAP_STATUS_BUSY, 8'h00, '0);
        engine_state_q <= ENG_ERROR;
      end else begin
        unique case (engine_state_q)
          ENG_IDLE: begin
            m_axi_bready_o <= '0;
            m_axi_rready_o <= '0;
            if (cmd_event) begin
              active_seq_q <= cmd_seq;
              if (parser_error) begin
                error_o <= '1;
                start_response(cmd_seq, parser_error_status,
                  8'h00, '0);
                engine_state_q <= ENG_RESP;
              end else begin
                error_o <= '0;
                unique case (cmd_code)
                  DAP_CMD_PING: begin
                    start_response(cmd_seq, DAP_STATUS_OK,
                      8'h00, '0);
                    engine_state_q <= ENG_RESP;
                  end
                  DAP_CMD_ID: begin
                    start_response(cmd_seq, DAP_STATUS_OK,
                      8'd8, {192'h0, "DAPBIN01"});
                    engine_state_q <= ENG_RESP;
                  end
                  DAP_CMD_UNLOCK: begin
                    if (cmd_len == 8'd4 &&
                        cmd_payload[31:0] ==
                        UNLOCK_KEY) begin
                      unlocked_q <= '1;
                      start_response(cmd_seq,
                        DAP_STATUS_OK, 8'h00, '0);
                    end else begin
                      unlocked_q <= '0;
                      error_o <= '1;
                      start_response(cmd_seq,
                        DAP_STATUS_LOCKED, 8'h00, '0);
                    end
                    engine_state_q <= ENG_RESP;
                  end
                  DAP_CMD_LOCK: begin
                    unlocked_q <= '0;
                    core_hold_o <= '0;
                    start_response(cmd_seq,
                      DAP_STATUS_OK, 8'h00, '0);
                    engine_state_q <= ENG_RESP;
                  end
                  DAP_CMD_HOLD_CORE: begin
                    if (!unlocked_q) begin
                      error_o <= '1;
                      start_response(cmd_seq,
                        DAP_STATUS_LOCKED, 8'h00, '0);
                      engine_state_q <= ENG_RESP;
                    end else if (cmd_len == 8'd1) begin
                      core_hold_o <= cmd_payload[0];
                      core_release_override_o <=
                        !cmd_payload[0];
                      start_response(cmd_seq,
                        DAP_STATUS_OK, 8'h00, '0);
                      engine_state_q <= ENG_RESP;
                    end else begin
                      error_o <= '1;
                      start_response(cmd_seq,
                        DAP_STATUS_BAD_LEN, 8'h00, '0);
                      engine_state_q <= ENG_RESP;
                    end
                  end
                  DAP_CMD_READ32: begin
                    if (cmd_len != 8'd2) begin
                      error_o <= '1;
                      start_response(cmd_seq,
                        DAP_STATUS_BAD_LEN, 8'h00, '0);
                      engine_state_q <= ENG_RESP;
                    end else begin
                      m_axi_araddr_o <=
                        cmd_payload[15:0];
                      m_axi_arvalid_o <= '1;
                      m_axi_rready_o <= '1;
                      engine_state_q <= ENG_AXI_READ;
                    end
                  end
                  DAP_CMD_WRITE32: begin
                    if (!unlocked_q) begin
                      error_o <= '1;
                      start_response(cmd_seq,
                        DAP_STATUS_LOCKED, 8'h00, '0);
                      engine_state_q <= ENG_RESP;
                    end else if (cmd_len != 8'd6) begin
                      error_o <= '1;
                      start_response(cmd_seq,
                        DAP_STATUS_BAD_LEN, 8'h00, '0);
                      engine_state_q <= ENG_RESP;
                    end else begin
                      m_axi_awaddr_o <=
                        cmd_payload[15:0];
                      m_axi_wdata_o <=
                        cmd_payload[47:16];
                      m_axi_wstrb_o <= 4'hf;
                      m_axi_awvalid_o <= '1;
                      m_axi_wvalid_o <= '1;
                      m_axi_bready_o <= '1;
                      engine_state_q <= ENG_AXI_WRITE;
                    end
                  end
                  DAP_CMD_ROM_WRITE: begin
                    if (!unlocked_q) begin
                      error_o <= '1;
                      start_response(cmd_seq,
                        DAP_STATUS_LOCKED, 8'h00, '0);
                      engine_state_q <= ENG_RESP;
                    end else if (cmd_len < 8'd6) begin
                      error_o <= '1;
                      start_response(cmd_seq,
                        DAP_STATUS_BAD_LEN, 8'h00, '0);
                      engine_state_q <= ENG_RESP;
                    end else if (!chunk_ready) begin
                      error_o <= '1;
                      start_response(cmd_seq,
                        DAP_STATUS_BUSY, 8'h00, '0);
                      engine_state_q <= ENG_RESP;
                    end else begin
                      chunk_valid_q <= '1;
                      engine_state_q <= ENG_ROM_WAIT;
                    end
                  end
                  DAP_CMD_GET_STATUS: begin
                    start_response(cmd_seq, DAP_STATUS_OK,
                      8'd2, {240'h0, chunk_expected_seq,
                      7'h00, locked_o});
                    engine_state_q <= ENG_RESP;
                  end
                  default: begin
                    error_o <= '1;
                    start_response(cmd_seq,
                      DAP_STATUS_BAD_CMD, 8'h00, '0);
                    engine_state_q <= ENG_RESP;
                  end
                endcase
              end
            end
          end
          ENG_AXI_WRITE: begin
            if (m_axi_bvalid_i) begin
              m_axi_bready_o <= '0;
              if (m_axi_bresp_i == 2'b00) begin
                start_response(active_seq_q, DAP_STATUS_OK,
                  8'h00, '0);
              end else begin
                error_o <= '1;
                start_response(active_seq_q,
                  DAP_STATUS_BUS_ERROR, 8'h00, '0);
              end
              engine_state_q <= ENG_RESP;
            end
          end
          ENG_AXI_READ: begin
            if (m_axi_rvalid_i) begin
              m_axi_rready_o <= '0;
              if (m_axi_rresp_i == 2'b00) begin
                start_response(active_seq_q, DAP_STATUS_OK,
                  8'd4, {224'h0, m_axi_rdata_i});
              end else begin
                error_o <= '1;
                start_response(active_seq_q,
                  DAP_STATUS_BUS_ERROR, 8'h00, '0);
              end
              engine_state_q <= ENG_RESP;
            end
          end
          ENG_ROM_WAIT: begin
            if (chunk_done) begin
              if (chunk_bad_seq) begin
                error_o <= '1;
                start_response(active_seq_q,
                  DAP_STATUS_BAD_SEQ, 8'd1,
                  {248'h0, chunk_expected_seq});
              end else if (chunk_bad_crc) begin
                error_o <= '1;
                start_response(active_seq_q,
                  DAP_STATUS_ROM_CRC, 8'h00, '0);
              end else begin
                start_response(active_seq_q, DAP_STATUS_OK,
                  8'h00, '0);
              end
              engine_state_q <= ENG_RESP;
            end
          end
          ENG_RESP,
          ENG_ERROR: begin
            if (!resp_active_q && !tx_busy) begin
              engine_state_q <= ENG_IDLE;
            end
          end
          default: engine_state_q <= ENG_IDLE;
        endcase
      end
    end
  end

  logic unused_status;
  assign unused_status = rx_fifo_full ^ rx_fifo_empty ^ rx_fifo_overflow ^
    tx_fifo_full ^ tx_fifo_empty ^ tx_fifo_overflow;

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_ff @(posedge clk_i) begin
    if (rst_ni && $past(rst_ni)) begin
      if (!unlocked_q) begin
        assert (!m_axi_awvalid_o);
        assert (!m_axi_wvalid_o);
        assert (!m_axi_bready_o);
        assert (!rom_load_valid_o);
        assert (!core_hold_o);
        assert (!core_release_override_o);
      end
      if ($past(m_axi_awvalid_o && !m_axi_awready_i)) begin
        assert (m_axi_awvalid_o);
        assert (m_axi_awaddr_o == $past(m_axi_awaddr_o));
      end
      if ($past(m_axi_wvalid_o && !m_axi_wready_i)) begin
        assert (m_axi_wvalid_o);
        assert (m_axi_wdata_o == $past(m_axi_wdata_o));
        assert (m_axi_wstrb_o == $past(m_axi_wstrb_o));
      end
      if ($past(m_axi_arvalid_o && !m_axi_arready_i)) begin
        assert (m_axi_arvalid_o);
        assert (m_axi_araddr_o == $past(m_axi_araddr_o));
      end
    end
  end
`endif
endmodule

`default_nettype wire

// EOF
