// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_uart_rx.sv
// -----------------------------------------------------------------------------
// @brief UART receiver.
// =============================================================================
//
// Responsibilities:
// - Sample start, data and stop bits from the line.
// - Produce a stable byte-valid pulse for the consumer.
// - Keep oversampling and framing behavior visible.
//
// Characteristics:
// - Bit-serial receive state machine.
// - Uses synchronizer stages before sampling.
// - Designed for debug and console paths.
//
// Design notes:
// - Keep the center sample point and bit count named.
// =============================================================================
`default_nettype none

module chip8_uart_rx #(
  parameter int unsigned CLK_HZ = 27_000_000,
  parameter int unsigned BAUD   = 115_200
) (
  input  logic       clk_i,
  input  logic       rst_ni,
  input  logic       rx_i,
  output logic       valid_o,
  output logic [7:0] data_o
);

  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int unsigned UART_RX_DATA_BITS         = 8;
  localparam int unsigned UART_RX_STATE_WIDTH       = 2;
  localparam int unsigned UART_RX_DIV_COUNTER_WIDTH = 32;
  localparam int unsigned UART_RX_BIT_COUNTER_WIDTH = 3;

  localparam logic UART_RX_IDLE_LEVEL  = '1;
  localparam logic UART_RX_START_LEVEL = '0;

  localparam int unsigned UART_RX_LSB_INDEX       = 0;
  localparam int unsigned UART_RX_MSB_INDEX       = UART_RX_DATA_BITS - 1;
  localparam int unsigned UART_RX_LAST_BIT        = UART_RX_DATA_BITS - 1;
  localparam int unsigned UART_RX_HALF_BIT_DIVIDE = 2;

  localparam int unsigned BAUD_DIV_RAW = CLK_HZ / BAUD;
  localparam int unsigned BAUD_DIV =
    (BAUD_DIV_RAW < 1) ? 1 : BAUD_DIV_RAW;

  // ------------------------------------------------------------
  // Type declarations
  // ------------------------------------------------------------

  // UART receiver state machine.
  //
  // Responsibilities:
  // - Qualify the start bit before shifting payload data.
  // - Count exactly one configured data byte.
  // - Emit data_valid_o after a valid stop-bit phase.
  typedef enum logic [UART_RX_STATE_WIDTH-1:0] {
    UART_RX_STATE_IDLE,
    UART_RX_STATE_START,
    UART_RX_STATE_DATA,
    UART_RX_STATE_STOP
  } uart_rx_state_e;

  uart_rx_state_e state_q;
  uart_rx_state_e state_d;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [UART_RX_DIV_COUNTER_WIDTH-1:0] div_q;
  logic [UART_RX_DIV_COUNTER_WIDTH-1:0] div_d;
  logic [UART_RX_BIT_COUNTER_WIDTH-1:0] bit_q;
  logic [UART_RX_BIT_COUNTER_WIDTH-1:0] bit_d;
  logic [UART_RX_DATA_BITS-1:0]         shift_q;
  logic [UART_RX_DATA_BITS-1:0]         shift_d;
  logic                                 rx_meta_q;
  logic                                 rx_meta_d;
  logic                                 rx_sync_q;
  logic                                 rx_sync_d;
  logic                                 valid_q;
  logic                                 valid_d;
  logic [UART_RX_DATA_BITS-1:0]         data_q;
  logic [UART_RX_DATA_BITS-1:0]         data_d;
  logic                                 baud_done;
  logic                                 half_bit_done;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign baud_done = div_q == UART_RX_DIV_COUNTER_WIDTH'(BAUD_DIV - 1);
  assign half_bit_done = div_q == UART_RX_DIV_COUNTER_WIDTH'(
    BAUD_DIV / UART_RX_HALF_BIT_DIVIDE);
  assign rx_meta_d = rx_i;
  assign rx_sync_d = rx_meta_q;
  assign valid_o = valid_q;
  assign data_o = data_q;

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    state_d = state_q;
    div_d = div_q;
    bit_d = bit_q;
    shift_d = shift_q;
    valid_d = '0;
    data_d = data_q;

    unique case (state_q)
      UART_RX_STATE_IDLE: begin
        div_d = '0;
        bit_d = '0;

        if (rx_sync_q == UART_RX_START_LEVEL) begin
          state_d = UART_RX_STATE_START;
        end
      end

      UART_RX_STATE_START: begin
        if (half_bit_done) begin
          div_d = '0;
          state_d = (rx_sync_q == UART_RX_START_LEVEL)
                ? UART_RX_STATE_DATA
                : UART_RX_STATE_IDLE;
        end else begin
          div_d = div_q + 1'b1;
        end
      end

      UART_RX_STATE_DATA: begin
        if (baud_done) begin
          div_d = '0;
          shift_d = {rx_sync_q, shift_q[UART_RX_MSB_INDEX:1]};

          if (bit_q ==
              UART_RX_BIT_COUNTER_WIDTH'(UART_RX_LAST_BIT)) begin
            bit_d = '0;
            state_d = UART_RX_STATE_STOP;
          end else begin
            bit_d = bit_q + 1'b1;
          end
        end else begin
          div_d = div_q + 1'b1;
        end
      end

      UART_RX_STATE_STOP: begin
        if (baud_done) begin
          div_d = '0;
          data_d = shift_q;
          valid_d = '1;
          state_d = UART_RX_STATE_IDLE;
        end else begin
          div_d = div_q + 1'b1;
        end
      end

      default: begin
        state_d = UART_RX_STATE_IDLE;
        div_d = '0;
        bit_d = '0;
        shift_d = '0;
        valid_d = '0;
        data_d = '0;
      end
    endcase
  end

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      state_q   <= UART_RX_STATE_IDLE;
      div_q     <= '0;
      bit_q     <= '0;
      shift_q   <= '0;
      rx_meta_q <= UART_RX_IDLE_LEVEL;
      rx_sync_q <= UART_RX_IDLE_LEVEL;
      valid_q   <= '0;
      data_q    <= '0;
    end else begin
      state_q   <= state_d;
      div_q     <= div_d;
      bit_q     <= bit_d;
      shift_q   <= shift_d;
      rx_meta_q <= rx_meta_d;
      rx_sync_q <= rx_sync_d;
      valid_q   <= valid_d;
      data_q    <= data_d;
    end
  end

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      assert(
        (state_q == UART_RX_STATE_IDLE) ||
        (state_q == UART_RX_STATE_START) ||
        (state_q == UART_RX_STATE_DATA) ||
        (state_q == UART_RX_STATE_STOP)
      );
    end
  end
`endif

endmodule

`default_nettype wire

// EOF
