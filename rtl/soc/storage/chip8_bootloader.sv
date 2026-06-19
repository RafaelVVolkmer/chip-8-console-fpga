// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_bootloader.sv
// -----------------------------------------------------------------------------
// @brief Bootloader and ROM staging controller.
// =============================================================================
//
// Responsibilities:
// - Coordinate SD loading, ROM staging and core release.
// - Expose boot status and error state to software.
// - Keep the boot flow and register contract explicit.
//
// Characteristics:
// - Boot-path FSM with software-visible status.
// - Owns the transition from storage to running core.
// - Leaves SD transport and ROM writes to helper blocks.
//
// Design notes:
// - Keep every boot phase and register offset named.
// =============================================================================
`default_nettype none

module chip8_bootloader #(
  parameter int DEFAULT_ROM_BYTES = 512
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  output logic        core_rst_no,

  output logic        sd_read_start_o,
  output logic [31:0] sd_lba_o,
  output logic [15:0] sd_length_o,
  input  logic        sd_busy_i,
  input  logic        sd_done_i,
  input  logic        sd_error_i,
  input  logic        sd_stream_valid_i,
  input  logic [7:0]  sd_stream_data_i,
  input  logic [15:0] sd_stream_offset_i,

  output logic        rom_load_valid_o,
  input  logic        rom_load_ready_i,
  output logic [11:0] rom_load_offset_o,
  output logic [7:0]  rom_load_data_o,

  output logic        log_valid_o,
  output logic [7:0]  log_data_o,
  input  logic        log_ready_i,

  output logic        irq_done_o,
  output logic        irq_error_o,

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

  // Bootloader state machine for reset hold, SD streaming and core release.
  //
  // Responsibilities:
  // - Keep the CPU reset asserted until a ROM image is loaded or boot is
  //   disabled.
  // - Serialize short boot/run/error log messages without extra buffering.
  // - Convert SD stream completion or error into sticky IRQ pulses.
  typedef enum logic [2:0] {
    CHIP8_BOOTLOADER_STATE_RESET,
    CHIP8_BOOTLOADER_STATE_LOG_BOOT,
    CHIP8_BOOTLOADER_STATE_START_SD,
    CHIP8_BOOTLOADER_STATE_LOAD,
    CHIP8_BOOTLOADER_STATE_LOG_RUN,
    CHIP8_BOOTLOADER_STATE_RELEASE,
    CHIP8_BOOTLOADER_STATE_LOG_ERROR
  } boot_state_t;

  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [7:0] BOOT_CTRL_OFFSET = 8'h00;
  localparam logic [7:0] BOOT_STATUS_OFFSET = 8'h04;
  localparam logic [7:0] BOOT_LBA_OFFSET = 8'h08;
  localparam logic [7:0] BOOT_LENGTH_OFFSET = 8'h0c;
  localparam logic [7:0] BOOT_LOADED_OFFSET = 8'h10;

  localparam int unsigned BOOT_CTRL_ENABLE_BIT = 0;
  localparam int unsigned BOOT_CTRL_START_BIT = 1;
  localparam int unsigned BOOT_CTRL_RELEASE_BIT = 2;

  localparam logic [3:0] BOOT_LOG_LAST_INDEX = 4'd4;
  localparam logic [3:0] RUN_LOG_LAST_INDEX = 4'd3;
  localparam logic [3:0] ERR_LOG_LAST_INDEX = 4'd3;

  boot_state_t state_q;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic        enable_q;
  logic        released_q;
  logic        error_q;
  logic        done_q;
  logic [31:0] lba_q;
  logic [15:0] length_q;
  logic [15:0] loaded_q;
  logic [3:0]  log_idx_q;
  logic        manual_start;
  logic [7:0]  boot_log_byte;
  logic [7:0]  run_log_byte;
  logic [7:0]  err_log_byte;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign reg_ready_o = reg_valid_i;
  assign manual_start =
    reg_valid_i && reg_we_i && reg_addr_i == BOOT_CTRL_OFFSET &&
    reg_wstrb_i[0] && reg_wdata_i[BOOT_CTRL_START_BIT];
  assign core_rst_no = rst_ni && (!enable_q || released_q);
  assign sd_lba_o = lba_q;
  assign sd_length_o = length_q;
  assign rom_load_valid_o =
    (state_q == CHIP8_BOOTLOADER_STATE_LOAD) &&
    sd_stream_valid_i;
  assign rom_load_offset_o = sd_stream_offset_i[11:0];
  assign rom_load_data_o = sd_stream_data_i;
  assign irq_done_o = done_q;
  assign irq_error_o = error_q;

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin : boot_log_mux_comb
    unique case (log_idx_q)
      4'd0: boot_log_byte = "B";
      4'd1: boot_log_byte = "O";
      4'd2: boot_log_byte = "O";
      4'd3: boot_log_byte = "T";
      4'd4: boot_log_byte = "\n";
      default: boot_log_byte = '0;
    endcase

    unique case (log_idx_q)
      4'd0: run_log_byte = "R";
      4'd1: run_log_byte = "U";
      4'd2: run_log_byte = "N";
      4'd3: run_log_byte = "\n";
      default: run_log_byte = '0;
    endcase

    unique case (log_idx_q)
      4'd0: err_log_byte = "E";
      4'd1: err_log_byte = "R";
      4'd2: err_log_byte = "R";
      4'd3: err_log_byte = "\n";
      default: err_log_byte = '0;
    endcase
  end

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : bootloader_ff
    if (!rst_ni) begin
      state_q         <= CHIP8_BOOTLOADER_STATE_RESET;
      enable_q        <= '1;
      released_q      <= '0;
      error_q         <= '0;
      done_q          <= '0;
      lba_q           <= '0;
      length_q        <= DEFAULT_ROM_BYTES[15:0];
      loaded_q        <= '0;
      log_idx_q       <= '0;
      sd_read_start_o <= '0;
      log_valid_o     <= '0;
      log_data_o      <= '0;
    end else begin
      sd_read_start_o <= '0;
      log_valid_o     <= '0;
      done_q          <= '0;
      error_q         <= '0;

      if (reg_valid_i && reg_we_i) begin
        unique case (reg_addr_i)
          BOOT_CTRL_OFFSET: if (reg_wstrb_i[0]) begin
            enable_q <= reg_wdata_i[BOOT_CTRL_ENABLE_BIT];
            if (reg_wdata_i[BOOT_CTRL_RELEASE_BIT]) begin
              released_q <= '1;
            end
          end
          BOOT_LBA_OFFSET: lba_q <= reg_wdata_i;
          BOOT_LENGTH_OFFSET: if (reg_wstrb_i[0] || reg_wstrb_i[1]) begin
            length_q <= reg_wdata_i[15:0];
          end
          default: begin end
        endcase
      end

      unique case (state_q)
        CHIP8_BOOTLOADER_STATE_RESET: begin
          released_q <= !enable_q;
          loaded_q   <= '0;
          log_idx_q  <= '0;
          if (enable_q || manual_start) begin
            state_q <= CHIP8_BOOTLOADER_STATE_LOG_BOOT;
          end
        end

        CHIP8_BOOTLOADER_STATE_LOG_BOOT: begin
          if (log_ready_i) begin
            log_valid_o <= '1;
            log_data_o  <= boot_log_byte;
            if (log_idx_q == BOOT_LOG_LAST_INDEX) begin
              log_idx_q <= '0;
              state_q   <= CHIP8_BOOTLOADER_STATE_START_SD;
            end else begin
              log_idx_q <= log_idx_q + 1'b1;
            end
          end
        end

        CHIP8_BOOTLOADER_STATE_START_SD: begin
          if (!sd_busy_i) begin
            sd_read_start_o <= '1;
            state_q         <= CHIP8_BOOTLOADER_STATE_LOAD;
          end
        end

        CHIP8_BOOTLOADER_STATE_LOAD: begin
          if (sd_stream_valid_i && rom_load_ready_i) begin
            loaded_q <= sd_stream_offset_i + 1'b1;
          end
          if (sd_error_i) begin
            log_idx_q <= '0;
            state_q   <= CHIP8_BOOTLOADER_STATE_LOG_ERROR;
          end else if (sd_done_i) begin
            log_idx_q <= '0;
            state_q   <= CHIP8_BOOTLOADER_STATE_LOG_RUN;
          end
        end

        CHIP8_BOOTLOADER_STATE_LOG_RUN: begin
          if (log_ready_i) begin
            log_valid_o <= '1;
            log_data_o  <= run_log_byte;
            if (log_idx_q == RUN_LOG_LAST_INDEX) begin
              log_idx_q  <= '0;
              released_q <= '1;
              done_q     <= '1;
              state_q    <= CHIP8_BOOTLOADER_STATE_RELEASE;
            end else begin
              log_idx_q <= log_idx_q + 1'b1;
            end
          end
        end

        CHIP8_BOOTLOADER_STATE_RELEASE: begin
          released_q <= '1;
          if (manual_start) begin
            released_q <= '0;
            loaded_q   <= '0;
            state_q    <= CHIP8_BOOTLOADER_STATE_LOG_BOOT;
          end
        end

        CHIP8_BOOTLOADER_STATE_LOG_ERROR: begin
          if (log_ready_i) begin
            log_valid_o <= '1;
            log_data_o  <= err_log_byte;
            if (log_idx_q == ERR_LOG_LAST_INDEX) begin
              log_idx_q <= '0;
              error_q   <= '1;
              state_q   <= CHIP8_BOOTLOADER_STATE_RESET;
            end else begin
              log_idx_q <= log_idx_q + 1'b1;
            end
          end
        end

        default: state_q <= CHIP8_BOOTLOADER_STATE_RESET;
      endcase
    end
  end

  always_comb begin : boot_regs_read_comb
    unique case (reg_addr_i)
      BOOT_CTRL_OFFSET: reg_rdata_o = {29'h0, released_q, 1'b0, enable_q};
      BOOT_STATUS_OFFSET: reg_rdata_o = {25'h0, error_q, done_q, sd_busy_i,
        released_q, state_q};
      BOOT_LBA_OFFSET: reg_rdata_o = lba_q;
      BOOT_LENGTH_OFFSET: reg_rdata_o = {16'h0000, length_q};
      BOOT_LOADED_OFFSET: reg_rdata_o = {16'h0000, loaded_q};
      default: reg_rdata_o = '0;
    endcase
  end
endmodule

`default_nettype wire

// EOF
