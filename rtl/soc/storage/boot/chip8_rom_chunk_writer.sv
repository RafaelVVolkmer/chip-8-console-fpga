// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_rom_chunk_writer.sv
// -----------------------------------------------------------------------------
// @brief ROM chunk writer and CRC checker.
// =============================================================================
//
// Responsibilities:
// - Validate chunk CRC before accepting ROM bytes.
// - Write bytes sequentially into the ROM load path.
// - Return the expected sequence and completion state.
//
// Characteristics:
// - Packet validation plus byte-stream writer.
// - Uses a small FSM and explicit CRC state.
// - Shared by the bootloader and DAP loader.
//
// Design notes:
// - Keep the CRC seed and byte ordering named.
// =============================================================================
`default_nettype none

module chip8_rom_chunk_writer #(
  parameter int OFFSET_WIDTH = 12,
  parameter int LEN_WIDTH = 5,
  parameter int MAX_CHUNK_BYTES = 16
) (
  input  logic                    clk_i,
  input  logic                    rst_ni,

  input  logic                    chunk_valid_i,
  output logic                    chunk_ready_o,
  input  logic [7:0]              chunk_seq_i,
  input  logic [OFFSET_WIDTH-1:0] chunk_offset_i,
  input  logic [LEN_WIDTH-1:0]    chunk_len_i,
  input  logic [MAX_CHUNK_BYTES*8-1:0] chunk_data_i,
  input  logic [15:0]             chunk_crc_i,

  output logic                    rom_valid_o,
  input  logic                    rom_ready_i,
  output logic [OFFSET_WIDTH-1:0] rom_offset_o,
  output logic [7:0]              rom_data_o,

  output logic                    done_o,
  output logic                    bad_seq_o,
  output logic                    bad_crc_o,
  output logic [7:0]              expected_seq_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int CHUNK_INDEX_WIDTH = $clog2(MAX_CHUNK_BYTES);
  localparam logic [15:0] ROM_CHUNK_CRC_INIT = 16'hffff;

  // ------------------------------------------------------------
  // Type declarations
  // ------------------------------------------------------------

  // ROM chunk writer state machine for packet validation and byte writes.
  //
  // Responsibilities:
  // - Validate chunk CRC before accepting data.
  // - Write bytes sequentially into the ROM load path.
  // - Return a compact response status and expected sequence number.
  typedef enum logic [1:0] {
    CHIP8_ROM_CHUNK_WRITER_STATE_IDLE,
    CHIP8_ROM_CHUNK_WRITER_STATE_CRC,
    CHIP8_ROM_CHUNK_WRITER_STATE_WRITE,
    CHIP8_ROM_CHUNK_WRITER_STATE_RESP
  } state_e;

  state_e state_q;
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [7:0] seq_q;
  logic [OFFSET_WIDTH-1:0] offset_q;
  logic [LEN_WIDTH-1:0] len_q;
  logic [LEN_WIDTH-1:0] index_q;
  logic [MAX_CHUNK_BYTES*8-1:0] data_q;
  logic [15:0] crc_expected_q;
  logic [15:0] crc_q;
  logic [15:0] crc_d;
  logic [7:0] crc_byte;
  logic [OFFSET_WIDTH-1:0] index_offset;
  logic [CHUNK_INDEX_WIDTH+2:0] data_bit_index;
  logic [31:0] chunk_len_ext;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign chunk_ready_o = state_q == CHIP8_ROM_CHUNK_WRITER_STATE_IDLE;
  assign expected_seq_o = seq_q;
  assign rom_valid_o = state_q == CHIP8_ROM_CHUNK_WRITER_STATE_WRITE;
  assign index_offset = {{(OFFSET_WIDTH-LEN_WIDTH){1'b0}}, index_q};
  assign data_bit_index = {index_q[CHUNK_INDEX_WIDTH-1:0], 3'b000};
  assign chunk_len_ext = {{(32-LEN_WIDTH){1'b0}}, chunk_len_i};
  assign rom_offset_o = offset_q + index_offset;
  assign rom_data_o = data_q[data_bit_index +: 8];
  assign crc_byte = data_q[data_bit_index +: 8];

  chip8_crc16_ccitt u_crc (
    .crc_i(crc_q),
    .data_i(crc_byte),
    .crc_o(crc_d)
  );

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      state_q <= CHIP8_ROM_CHUNK_WRITER_STATE_IDLE;
      seq_q <= '0;
      offset_q <= '0;
      len_q <= '0;
      index_q <= '0;
      data_q <= '0;
      crc_expected_q <= '0;
      crc_q <= ROM_CHUNK_CRC_INIT;
      done_o <= '0;
      bad_seq_o <= '0;
      bad_crc_o <= '0;
    end else begin
      done_o <= '0;

      unique case (state_q)
        CHIP8_ROM_CHUNK_WRITER_STATE_IDLE: begin
          index_q <= '0;
          crc_q <= ROM_CHUNK_CRC_INIT;
          if (chunk_valid_i) begin
            bad_seq_o <= '0;
            bad_crc_o <= '0;
            offset_q <= chunk_offset_i;
            len_q <= chunk_len_i;
            data_q <= chunk_data_i;
            crc_expected_q <= chunk_crc_i;
            if (chunk_seq_i != seq_q) begin
              bad_seq_o <= '1;
              state_q <= CHIP8_ROM_CHUNK_WRITER_STATE_RESP;
            end else if (chunk_len_i == '0 ||
                chunk_len_ext > MAX_CHUNK_BYTES) begin
              bad_crc_o <= '1;
              state_q <= CHIP8_ROM_CHUNK_WRITER_STATE_RESP;
            end else begin
              state_q <= CHIP8_ROM_CHUNK_WRITER_STATE_CRC;
            end
          end
        end

        CHIP8_ROM_CHUNK_WRITER_STATE_CRC: begin
          crc_q <= crc_d;
          if (index_q + {{(LEN_WIDTH-1){1'b0}}, 1'b1} >= len_q) begin
            index_q <= '0;
            if (crc_d == crc_expected_q) begin
              state_q <= CHIP8_ROM_CHUNK_WRITER_STATE_WRITE;
            end else begin
              bad_crc_o <= '1;
              state_q <= CHIP8_ROM_CHUNK_WRITER_STATE_RESP;
            end
          end else begin
            index_q <= index_q + {{(LEN_WIDTH-1){1'b0}}, 1'b1};
          end
        end

        CHIP8_ROM_CHUNK_WRITER_STATE_WRITE: begin
          if (rom_ready_i) begin
            if (index_q + {{(LEN_WIDTH-1){1'b0}}, 1'b1} >=
                len_q) begin
              seq_q <= seq_q + 1'b1;
              state_q <= CHIP8_ROM_CHUNK_WRITER_STATE_RESP;
            end else begin
              index_q <= index_q +
                {{(LEN_WIDTH-1){1'b0}}, 1'b1};
            end
          end
        end

        CHIP8_ROM_CHUNK_WRITER_STATE_RESP: begin
          done_o <= '1;
          state_q <= CHIP8_ROM_CHUNK_WRITER_STATE_IDLE;
        end

        default: state_q <= CHIP8_ROM_CHUNK_WRITER_STATE_IDLE;
      endcase
    end
  end

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_ff @(posedge clk_i) begin
    if (rst_ni && $past(rst_ni)) begin
      if ($past(rom_valid_o && !rom_ready_i)) begin
        assert (rom_valid_o);
        assert (rom_offset_o == $past(rom_offset_o));
        assert (rom_data_o == $past(rom_data_o));
      end
      assert (index_q <= MAX_CHUNK_BYTES[LEN_WIDTH-1:0]);
    end
  end
`endif
endmodule

`default_nettype wire

// EOF
