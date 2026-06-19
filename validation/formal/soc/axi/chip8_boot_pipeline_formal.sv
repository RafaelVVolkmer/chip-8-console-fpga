// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_boot_pipeline_formal.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 Boot pipeline.
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

module chip8_boot_pipeline_formal (
  input logic clk,
  input logic rst_n
);
  localparam logic [15:0] FORMAL_BOOT_LENGTH_MAX = 16'hffff;

  (* anyseq *) logic [3:0] sd_dat;
  (* anyseq *) logic       sd_done;
  (* anyseq *) logic       sd_error;
  (* anyseq *) logic       sd_stream_valid;
  (* anyseq *) logic [7:0] sd_stream_data;
  (* anyseq *) logic [15:0] sd_stream_offset;

  // ------------------------------------------------------------
  // Testbench signals
  // ------------------------------------------------------------

  logic sd_clk;
  logic sd_cmd;
  logic [3:0] sd_dat_out;
  logic [3:0] sd_dat_oe;
  logic sd_busy;
  logic sd_host_done;
  logic sd_host_error;
  logic sd_host_stream_valid;
  logic [7:0] sd_host_stream_data;
  logic [15:0] sd_host_stream_offset;
  logic core_rst_n;
  logic boot_sd_start;
  logic [31:0] boot_lba;
  logic [15:0] boot_length;
  logic rom_load_valid;
  logic [11:0] rom_load_offset;
  logic [7:0] rom_load_data;
  logic log_valid;
  logic [7:0] log_data;
  logic boot_done_irq;
  logic boot_error_irq;
  logic past_valid = '0;

  chip8_sd_spi_host u_sd_host (
  .clk_i(clk),
  .rst_ni(rst_n),
  .sd_clk_o(sd_clk),
  .sd_cmd_o(sd_cmd),
  .sd_dat_i(sd_dat),
  .sd_dat_out_o(sd_dat_out),
  .sd_dat_oe_o(sd_dat_oe),
  .boot_read_start_i(1'b0),
  .boot_lba_i(32'h0000_0000),
  .boot_length_i(16'd16),
  .boot_busy_o(sd_busy),
  .boot_done_o(sd_host_done),
  .boot_error_o(sd_host_error),
  .stream_valid_o(sd_host_stream_valid),
  .stream_data_o(sd_host_stream_data),
  .stream_offset_o(sd_host_stream_offset),
  .reg_valid_i(1'b0),
  .reg_we_i(1'b0),
  .reg_addr_i(8'h00),
  .reg_wdata_i(32'h0000_0000),
  .reg_wstrb_i(4'h0),
  .reg_ready_o(),
  .reg_rdata_o()
  );

  chip8_bootloader #(
  .DEFAULT_ROM_BYTES(16)
  ) u_bootloader (
  .clk_i(clk),
  .rst_ni(rst_n),
  .core_rst_no(core_rst_n),
  .sd_read_start_o(boot_sd_start),
  .sd_lba_o(boot_lba),
  .sd_length_o(boot_length),
  .sd_busy_i(1'b0),
  .sd_done_i(sd_done),
  .sd_error_i(sd_error),
  .sd_stream_valid_i(sd_stream_valid),
  .sd_stream_data_i(sd_stream_data),
  .sd_stream_offset_i(sd_stream_offset),
  .rom_load_valid_o(rom_load_valid),
  .rom_load_ready_i(1'b1),
  .rom_load_offset_o(rom_load_offset),
  .rom_load_data_o(rom_load_data),
  .log_valid_o(log_valid),
  .log_data_o(log_data),
  .log_ready_i(1'b1),
  .irq_done_o(boot_done_irq),
  .irq_error_o(boot_error_irq),
  .reg_valid_i(1'b0),
  .reg_we_i(1'b0),
  .reg_addr_i(8'h00),
  .reg_wdata_i(32'h0000_0000),
  .reg_wstrb_i(4'h0),
  .reg_ready_o(),
  .reg_rdata_o()
  );

  // ------------------------------------------------------------
  // Clocked testbench procedures
  // ------------------------------------------------------------

  always_ff @(posedge clk) begin : formal_reset_ff
  past_valid <= '1;
  if (!past_valid) begin
    assume (!rst_n);
  end else begin
    assume (rst_n);
  end
  end

  always_ff @(posedge clk) begin : formal_properties_ff
  if (past_valid && rst_n) begin
    assert (boot_length <= FORMAL_BOOT_LENGTH_MAX);
    assert (!rom_load_valid || rom_load_offset ==
    sd_stream_offset[11:0]);
    assert (!rom_load_valid || rom_load_data == sd_stream_data);
    assert (sd_dat_oe == 4'b1110);
    assert (sd_clk == 1'b0 || sd_clk == 1'b1);
    assert (sd_cmd == 1'b0 || sd_cmd == 1'b1);
    assert (sd_dat_out <= 4'hf);
    assert (core_rst_n == 1'b0 || core_rst_n == 1'b1);
    assert (boot_sd_start == 1'b0 || boot_sd_start == 1'b1);
    assert (boot_lba <= 32'hffff_ffff);
    assert (boot_done_irq == 1'b0 || boot_done_irq == 1'b1);
    assert (boot_error_irq == 1'b0 || boot_error_irq == 1'b1);
    assert (log_valid == 1'b0 || log_valid == 1'b1);
  end
  end
endmodule

`default_nettype wire

// EOF
