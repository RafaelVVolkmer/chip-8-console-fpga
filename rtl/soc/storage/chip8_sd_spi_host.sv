// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_sd_spi_host.sv
// -----------------------------------------------------------------------------
// @brief SD card SPI host.
// =============================================================================
//
// Responsibilities:
// - Issue SD commands and stream block data over SPI.
// - Track read status, byte counts and CRC state.
// - Expose boot-time storage access through registers.
//
// Characteristics:
// - Protocol-heavy peripheral controller.
// - Owns command timing and data framing state.
// - Pairs with the bootloader and ROM writer.
//
// Design notes:
// - Keep every command opcode and token named.
// =============================================================================
`default_nettype none

module chip8_sd_spi_host #(
  parameter int DEFAULT_LENGTH = 512,
  parameter int TIMEOUT_CYCLES = 4096,
  parameter bit SIM_BOOT_ROM = 1'b0
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  output logic        sd_clk_o,
  output logic        sd_cmd_o,
  input  logic [3:0]  sd_dat_i,
  output logic [3:0]  sd_dat_out_o,
  output logic [3:0]  sd_dat_oe_o,

  input  logic        boot_read_start_i,
  input  logic [31:0] boot_lba_i,
  input  logic [15:0] boot_length_i,
  output logic        boot_busy_o,
  output logic        boot_done_o,
  output logic        boot_error_o,
  output logic        stream_valid_o,
  output logic [7:0]  stream_data_o,
  output logic [15:0] stream_offset_o,

  input  logic        reg_valid_i,
  input  logic        reg_we_i,
  input  logic [7:0]  reg_addr_i,
  input  logic [31:0] reg_wdata_i,
  input  logic [3:0]  reg_wstrb_i,
  output logic        reg_ready_o,
  output logic [31:0] reg_rdata_o
);
  // ------------------------------------------------------------
  // Type declarations
  // ------------------------------------------------------------

  // SD SPI host state machine for one-block-style command and byte streaming.
  //
  // Responsibilities:
  // - Issue a read command, wait for the data token and stream bytes.
  // - Track command/data CRC state for inspection.
  // - Provide a simulation boot-ROM path when external SD data is unavailable.
  typedef enum logic [2:0] {
    CHIP8_SD_SPI_HOST_STATE_IDLE,
    CHIP8_SD_SPI_HOST_STATE_CMD,
    CHIP8_SD_SPI_HOST_STATE_WAIT_TOKEN,
    CHIP8_SD_SPI_HOST_STATE_DATA,
    CHIP8_SD_SPI_HOST_STATE_CRC0,
    CHIP8_SD_SPI_HOST_STATE_CRC1,
    CHIP8_SD_SPI_HOST_STATE_DONE,
    CHIP8_SD_SPI_HOST_STATE_ERROR
  } sd_state_t;

  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [7:0] SD_CTRL_OFFSET = 8'h00;
  localparam logic [7:0] SD_STATUS_OFFSET = 8'h04;
  localparam logic [7:0] SD_LBA_OFFSET = 8'h08;
  localparam logic [7:0] SD_LENGTH_OFFSET = 8'h0c;
  localparam logic [7:0] SD_BYTE_COUNT_OFFSET = 8'h10;
  localparam logic [7:0] SD_TIMEOUT_OFFSET = 8'h14;
  localparam logic [7:0] SD_CRC16_OFFSET = 8'h18;

  localparam int unsigned SD_CTRL_START_BIT = 0;
  localparam logic [7:0] SD_CMD_READ_SINGLE_BLOCK = 8'h51;
  localparam logic [7:0] SD_DATA_START_TOKEN = 8'hfe;
  localparam logic [7:0] SD_SPI_IDLE_BYTE = 8'hff;
  localparam logic [47:0] SD_SPI_IDLE_CMD = 48'hffff_ffff_ffff;

  sd_state_t state_q;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [47:0] cmd_shift_q;
  logic [5:0]  cmd_bit_q;
  logic [2:0]  rx_bit_q;
  logic [7:0]  rx_shift_q;
  logic [7:0]  rx_byte;
  logic [31:0] lba_q;
  logic [15:0] length_q;
  logic [15:0] byte_count_q;
  logic [31:0] timeout_q;
  logic        done_q;
  logic        error_q;
  logic        start_reg;
  logic        start_req;
  logic        sample_tick;
  logic [6:0]  crc7_q;
  logic [6:0]  crc7_d;
  logic [15:0] crc16_q;
  logic [15:0] crc16_d;
  logic        crc_bit;
  logic [7:0]  cmd_crc_byte;
  logic        sd_cs_n;
  logic [7:0]  data_byte;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign reg_ready_o = reg_valid_i;
  assign start_reg =
    reg_valid_i && reg_we_i && reg_addr_i == SD_CTRL_OFFSET &&
    reg_wstrb_i[0] && reg_wdata_i[SD_CTRL_START_BIT];
  assign start_req = start_reg || boot_read_start_i;
  assign sample_tick =
    (state_q != CHIP8_SD_SPI_HOST_STATE_IDLE) &&
    (state_q != CHIP8_SD_SPI_HOST_STATE_DONE) &&
    (state_q != CHIP8_SD_SPI_HOST_STATE_ERROR) &&
    sd_clk_o;
  assign rx_byte = {rx_shift_q[6:0], sd_dat_i[0]};
  assign boot_busy_o =
    (state_q != CHIP8_SD_SPI_HOST_STATE_IDLE) &&
    (state_q != CHIP8_SD_SPI_HOST_STATE_DONE) &&
    (state_q != CHIP8_SD_SPI_HOST_STATE_ERROR);
  assign boot_done_o = done_q;
  assign boot_error_o = error_q;
  assign sd_cs_n =
    (state_q == CHIP8_SD_SPI_HOST_STATE_IDLE) ||
    (state_q == CHIP8_SD_SPI_HOST_STATE_DONE) ||
    (state_q == CHIP8_SD_SPI_HOST_STATE_ERROR);
  assign sd_dat_out_o = {sd_cs_n, 2'b11, 1'b1};
  assign sd_dat_oe_o = 4'b1110;
  assign crc_bit = (state_q == CHIP8_SD_SPI_HOST_STATE_CMD) ?
    cmd_shift_q[47] :
    sd_dat_i[0];
  assign cmd_crc_byte = {crc7_q, 1'b1};
  assign data_byte = SIM_BOOT_ROM ? sim_boot_rom_byte(byte_count_q) : rx_byte;

  // ------------------------------------------------------------
  // Function declarations
  // ------------------------------------------------------------

  function automatic logic [7:0] sim_boot_rom_byte(input logic [15:0] offset);
    unique case (offset)
      16'd0:  sim_boot_rom_byte = '0;
      16'd1:  sim_boot_rom_byte = 8'he0;
      16'd2:  sim_boot_rom_byte = 8'h60;
      16'd3:  sim_boot_rom_byte = 8'h08;
      16'd4:  sim_boot_rom_byte = 8'h61;
      16'd5:  sim_boot_rom_byte = 8'h08;
      16'd6:  sim_boot_rom_byte = 8'ha0;
      16'd7:  sim_boot_rom_byte = '0;
      16'd8:  sim_boot_rom_byte = 8'hd0;
      16'd9:  sim_boot_rom_byte = 8'h15;
      16'd10: sim_boot_rom_byte = 8'h70;
      16'd11: sim_boot_rom_byte = 8'h08;
      16'd12: sim_boot_rom_byte = 8'h62;
      16'd13: sim_boot_rom_byte = 8'h0a;
      16'd14: sim_boot_rom_byte = 8'h80;
      16'd15: sim_boot_rom_byte = 8'h24;
      16'd16: sim_boot_rom_byte = 8'ha0;
      16'd17: sim_boot_rom_byte = 8'h05;
      16'd18: sim_boot_rom_byte = 8'hd0;
      16'd19: sim_boot_rom_byte = 8'h15;
      16'd20: sim_boot_rom_byte = 8'h12;
      16'd21: sim_boot_rom_byte = 8'h14;
      default: sim_boot_rom_byte = '0;
    endcase
  endfunction

  chip8_sd_crc7 u_crc7 (
    .crc_i(crc7_q),
    .bit_i(crc_bit),
    .crc_o(crc7_d)
  );

  chip8_sd_crc16 u_crc16 (
    .crc_i(crc16_q),
    .bit_i(crc_bit),
    .crc_o(crc16_d)
  );

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : sd_host_ff
    if (!rst_ni) begin
      state_q         <= CHIP8_SD_SPI_HOST_STATE_IDLE;
      cmd_shift_q     <= SD_SPI_IDLE_CMD;
      cmd_bit_q       <= '0;
      rx_bit_q        <= '0;
      rx_shift_q      <= SD_SPI_IDLE_BYTE;
      lba_q           <= '0;
      length_q        <= DEFAULT_LENGTH[15:0];
      byte_count_q    <= '0;
      timeout_q       <= '0;
      done_q          <= '0;
      error_q         <= '0;
      sd_clk_o        <= '0;
      sd_cmd_o        <= '1;
      stream_valid_o  <= '0;
      stream_data_o   <= '0;
      stream_offset_o <= '0;
      crc7_q          <= '0;
      crc16_q         <= '0;
    end else begin
      stream_valid_o <= '0;
      done_q         <= '0;
      error_q        <= '0;

      if ((state_q != CHIP8_SD_SPI_HOST_STATE_IDLE) &&
          (state_q != CHIP8_SD_SPI_HOST_STATE_DONE) &&
          (state_q != CHIP8_SD_SPI_HOST_STATE_ERROR)) begin
        sd_clk_o <= !sd_clk_o;
      end else begin
        sd_clk_o <= '0;
      end

      if (reg_valid_i && reg_we_i) begin
        unique case (reg_addr_i)
          SD_LBA_OFFSET: lba_q <= reg_wdata_i;
          SD_LENGTH_OFFSET: if (reg_wstrb_i[0] || reg_wstrb_i[1]) begin
            length_q <= reg_wdata_i[15:0];
          end
          default: begin end
        endcase
      end

      unique case (state_q)
        CHIP8_SD_SPI_HOST_STATE_IDLE: begin
          sd_cmd_o     <= '1;
          cmd_bit_q    <= '0;
          rx_bit_q     <= '0;
          timeout_q    <= '0;
          byte_count_q <= '0;
          crc7_q       <= '0;
          crc16_q      <= '0;
          if (start_req) begin
            lba_q       <= start_reg ? lba_q : boot_lba_i;
            length_q    <= start_reg ? length_q : boot_length_i;
            cmd_shift_q <= {
              SD_CMD_READ_SINGLE_BLOCK,
              (start_reg ? lba_q : boot_lba_i),
              SD_SPI_IDLE_BYTE
            };
            state_q     <= CHIP8_SD_SPI_HOST_STATE_CMD;
          end
        end

        CHIP8_SD_SPI_HOST_STATE_CMD: begin
          if (sample_tick) begin
            sd_cmd_o    <= cmd_shift_q[47];
            cmd_shift_q <= {cmd_shift_q[46:0], 1'b1};
            crc7_q      <= crc7_d;
            if (cmd_bit_q == 6'd47) begin
              cmd_bit_q <= '0;
              state_q   <= CHIP8_SD_SPI_HOST_STATE_WAIT_TOKEN;
              sd_cmd_o  <= cmd_crc_byte[7];
            end else begin
              cmd_bit_q <= cmd_bit_q + 1'b1;
            end
          end
        end

        CHIP8_SD_SPI_HOST_STATE_WAIT_TOKEN: begin
          sd_cmd_o <= '1;
          if (SIM_BOOT_ROM) begin
            rx_bit_q <= '0;
            state_q  <= CHIP8_SD_SPI_HOST_STATE_DATA;
          end else if (sample_tick) begin
            rx_shift_q <= rx_byte;
            if (rx_bit_q == 3'd7) begin
              rx_bit_q <= '0;
              if (rx_byte == SD_DATA_START_TOKEN) begin
                state_q <= CHIP8_SD_SPI_HOST_STATE_DATA;
              end else if (timeout_q >= TIMEOUT_CYCLES[31:0])
                begin
                state_q <= CHIP8_SD_SPI_HOST_STATE_ERROR;
              end else begin
                timeout_q <= timeout_q + 1'b1;
              end
            end else begin
              rx_bit_q <= rx_bit_q + 1'b1;
            end
          end
        end

        CHIP8_SD_SPI_HOST_STATE_DATA: begin
          sd_cmd_o <= '1;
          if (sample_tick) begin
            rx_shift_q <= rx_byte;
            crc16_q    <= crc16_d;
            if (rx_bit_q == 3'd7) begin
              rx_bit_q       <= '0;
              stream_valid_o <= '1;
              stream_data_o  <= data_byte;
              stream_offset_o <= byte_count_q;
              if (byte_count_q == length_q - 1'b1) begin
                state_q <= CHIP8_SD_SPI_HOST_STATE_CRC0;
              end
              byte_count_q <= byte_count_q + 1'b1;
            end else begin
              rx_bit_q <= rx_bit_q + 1'b1;
            end
          end
        end

        CHIP8_SD_SPI_HOST_STATE_CRC0: begin
          if (sample_tick && rx_bit_q == 3'd7) begin
            rx_bit_q <= '0;
            state_q  <= CHIP8_SD_SPI_HOST_STATE_CRC1;
          end else if (sample_tick) begin
            rx_bit_q <= rx_bit_q + 1'b1;
          end
        end

        CHIP8_SD_SPI_HOST_STATE_CRC1: begin
          if (sample_tick && rx_bit_q == 3'd7) begin
            rx_bit_q <= '0;
            state_q  <= CHIP8_SD_SPI_HOST_STATE_DONE;
          end else if (sample_tick) begin
            rx_bit_q <= rx_bit_q + 1'b1;
          end
        end

        CHIP8_SD_SPI_HOST_STATE_DONE: begin
          done_q  <= '1;
          state_q <= CHIP8_SD_SPI_HOST_STATE_IDLE;
        end

        CHIP8_SD_SPI_HOST_STATE_ERROR: begin
          error_q <= '1;
          state_q <= CHIP8_SD_SPI_HOST_STATE_IDLE;
        end

        default: state_q <= CHIP8_SD_SPI_HOST_STATE_IDLE;
      endcase
    end
  end

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin : sd_regs_read_comb
    unique case (reg_addr_i)
      SD_CTRL_OFFSET: reg_rdata_o = '0;
      SD_STATUS_OFFSET: reg_rdata_o = {24'h0, error_q, done_q,
        boot_busy_o, 5'h00};
      SD_LBA_OFFSET: reg_rdata_o = lba_q;
      SD_LENGTH_OFFSET: reg_rdata_o = {16'h0000, length_q};
      SD_BYTE_COUNT_OFFSET: reg_rdata_o = {16'h0000, byte_count_q};
      SD_TIMEOUT_OFFSET: reg_rdata_o = timeout_q;
      SD_CRC16_OFFSET: reg_rdata_o = {16'h0000, crc16_q};
      default: reg_rdata_o = '0;
    endcase
  end
endmodule

`default_nettype wire

// EOF
