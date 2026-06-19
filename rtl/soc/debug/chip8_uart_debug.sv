// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_uart_debug.sv
// -----------------------------------------------------------------------------
// @brief UART debug and trace bridge.
// =============================================================================
//
// Responsibilities:
// - Serialize log traffic and read back debug bytes.
// - Keep UART framing independent from CPU state.
// - Expose deterministic debug status for bring-up.
//
// Characteristics:
// - Combines UART TX and RX with debug registers.
// - Does not own architectural CPU state.
// - Used for simulation, console and board debug.
//
// Design notes:
// - Keep TX, RX and status offsets named.
// =============================================================================
`default_nettype none

module chip8_uart_debug #(
  parameter int CLK_HZ = 27_000_000,
  parameter int BAUD = 115200
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  output logic        uart_tx_o,
  input  logic        uart_rx_i,

  input  logic        log_valid_i,
  input  logic [7:0]  log_data_i,
  output logic        log_ready_o,

  output logic        usb_artifact_valid_o,
  output logic [7:0]  usb_artifact_data_o,
  output logic        irq_rx_o,

  input  logic        reg_valid_i,
  input  logic        reg_we_i,
  input  logic [7:0]  reg_addr_i,
  input  logic [31:0] reg_wdata_i,
  input  logic [3:0]  reg_wstrb_i,
  output logic        reg_ready_o,
  output logic [31:0] reg_rdata_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int unsigned BAUD_DIV_RAW = CLK_HZ / BAUD;
  localparam int unsigned BAUD_DIV = (BAUD_DIV_RAW < 1) ? 1 : BAUD_DIV_RAW;
  localparam int unsigned BAUD_HALF_DIV = BAUD_DIV >> 1;
  localparam logic [7:0] UART_TX_OFFSET = 8'h00;
  localparam logic [7:0] UART_RX_OFFSET = 8'h04;
  localparam logic [7:0] UART_STATUS_OFFSET = 8'h08;
  localparam logic [7:0] UART_BAUD_DIV_OFFSET = 8'h0c;
  localparam logic [2:0] UART_LAST_DATA_BIT = 3'd7;

  // ------------------------------------------------------------
  // Type declarations
  // ------------------------------------------------------------

  // UART transmitter state for debug log bytes.
  //
  // Responsibilities:
  // - Serialize start bit, data bits and stop bit.
  // - Gate byte acceptance while a frame is in progress.
  typedef enum logic [1:0] {
    TX_IDLE,
    TX_START,
    TX_DATA,
    TX_STOP
  } tx_state_t;

  // UART receiver state for debug input bytes.
  //
  // Responsibilities:
  // - Detect a start bit and sample the byte center-aligned to the baud tick.
  // - Raise a byte-valid pulse after a complete stop bit.
  typedef enum logic [1:0] {
    RX_IDLE,
    RX_START,
    RX_DATA,
    RX_STOP
  } rx_state_t;

  tx_state_t tx_state_q;
  rx_state_t rx_state_q;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [31:0] tx_div_q;
  logic [31:0] rx_div_q;
  logic [2:0]  tx_bit_q;
  logic [2:0]  rx_bit_q;
  logic [7:0]  tx_shift_q;
  logic [7:0]  rx_shift_q;
  logic [7:0]  rx_data_q;
  logic        rx_valid_q;
  logic        tx_busy;
  logic        tx_start;
  logic [7:0]  tx_start_data;
  logic        reg_tx_write;
  logic        rx_sync0_q;
  logic        rx_sync1_q;
  logic        artifact_valid_q;
  logic [7:0]  artifact_data_q;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign tx_busy = tx_state_q != TX_IDLE;
  assign reg_tx_write = reg_valid_i && reg_we_i &&
    reg_addr_i == UART_TX_OFFSET && reg_wstrb_i[0];
  assign tx_start = (!tx_busy) && (log_valid_i || reg_tx_write);
  assign tx_start_data = log_valid_i ? log_data_i : reg_wdata_i[7:0];
  assign log_ready_o = !tx_busy;
  assign reg_ready_o = reg_valid_i;
  assign irq_rx_o = rx_valid_q;
  assign usb_artifact_valid_o = artifact_valid_q;
  assign usb_artifact_data_o = artifact_data_q;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : uart_tx_ff
    if (!rst_ni) begin
      tx_state_q <= TX_IDLE;
      tx_div_q   <= '0;
      tx_bit_q   <= '0;
      tx_shift_q <= '0;
      uart_tx_o  <= '1;
      artifact_valid_q <= '0;
      artifact_data_q  <= '0;
    end else begin
      artifact_valid_q <= tx_start;
      if (tx_start) begin
        artifact_data_q <= tx_start_data;
      end

      unique case (tx_state_q)
        TX_IDLE: begin
          uart_tx_o <= '1;
          tx_div_q  <= '0;
          tx_bit_q  <= '0;
          if (tx_start) begin
            tx_shift_q <= tx_start_data;
            tx_state_q <= TX_START;
          end
        end

        TX_START: begin
          uart_tx_o <= '0;
          if (tx_div_q == BAUD_DIV - 1) begin
            tx_div_q   <= '0;
            tx_state_q <= TX_DATA;
          end else begin
            tx_div_q <= tx_div_q + 1'b1;
          end
        end

        TX_DATA: begin
          uart_tx_o <= tx_shift_q[0];
          if (tx_div_q == BAUD_DIV - 1) begin
            tx_div_q   <= '0;
            tx_shift_q <= {1'b0, tx_shift_q[7:1]};
            if (tx_bit_q == UART_LAST_DATA_BIT) begin
              tx_bit_q   <= '0;
              tx_state_q <= TX_STOP;
            end else begin
              tx_bit_q <= tx_bit_q + 1'b1;
            end
          end else begin
            tx_div_q <= tx_div_q + 1'b1;
          end
        end

        TX_STOP: begin
          uart_tx_o <= '1;
          if (tx_div_q == BAUD_DIV - 1) begin
            tx_div_q   <= '0;
            tx_state_q <= TX_IDLE;
          end else begin
            tx_div_q <= tx_div_q + 1'b1;
          end
        end

        default: tx_state_q <= TX_IDLE;
      endcase
    end
  end

  always_ff @(posedge clk_i) begin : uart_rx_ff
    if (!rst_ni) begin
      rx_state_q <= RX_IDLE;
      rx_div_q   <= '0;
      rx_bit_q   <= '0;
      rx_shift_q <= '0;
      rx_data_q  <= '0;
      rx_valid_q <= '0;
      rx_sync0_q <= '1;
      rx_sync1_q <= '1;
    end else begin
      rx_sync0_q <= uart_rx_i;
      rx_sync1_q <= rx_sync0_q;

      if (reg_valid_i && !reg_we_i && reg_addr_i == UART_RX_OFFSET) begin
        rx_valid_q <= '0;
      end

      unique case (rx_state_q)
        RX_IDLE: begin
          rx_div_q <= '0;
          rx_bit_q <= '0;
          if (!rx_sync1_q) begin
            rx_state_q <= RX_START;
          end
        end

        RX_START: begin
          if (rx_div_q == BAUD_HALF_DIV) begin
            rx_div_q <= '0;
            if (!rx_sync1_q) begin
              rx_state_q <= RX_DATA;
            end else begin
              rx_state_q <= RX_IDLE;
            end
          end else begin
            rx_div_q <= rx_div_q + 1'b1;
          end
        end

        RX_DATA: begin
          if (rx_div_q == BAUD_DIV - 1) begin
            rx_div_q <= '0;
            rx_shift_q <= {rx_sync1_q, rx_shift_q[7:1]};
            if (rx_bit_q == UART_LAST_DATA_BIT) begin
              rx_bit_q   <= '0;
              rx_state_q <= RX_STOP;
            end else begin
              rx_bit_q <= rx_bit_q + 1'b1;
            end
          end else begin
            rx_div_q <= rx_div_q + 1'b1;
          end
        end

        RX_STOP: begin
          if (rx_div_q == BAUD_DIV - 1) begin
            rx_div_q   <= '0;
            rx_data_q  <= rx_shift_q;
            rx_valid_q <= '1;
            rx_state_q <= RX_IDLE;
          end else begin
            rx_div_q <= rx_div_q + 1'b1;
          end
        end

        default: rx_state_q <= RX_IDLE;
      endcase
    end
  end

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin : uart_regs_read_comb
    unique case (reg_addr_i)
      UART_TX_OFFSET: reg_rdata_o = {24'h0, tx_shift_q};
      UART_RX_OFFSET: reg_rdata_o = {24'h0, rx_data_q};
      UART_STATUS_OFFSET: reg_rdata_o = {30'h0, rx_valid_q, tx_busy};
      UART_BAUD_DIV_OFFSET: reg_rdata_o = BAUD_DIV[31:0];
      default: reg_rdata_o = '0;
    endcase
  end
endmodule

`default_nettype wire

// EOF
