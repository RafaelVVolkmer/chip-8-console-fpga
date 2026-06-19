// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_uart_tx.sv
// -----------------------------------------------------------------------------
// @brief UART transmitter.
// =============================================================================
//
// Responsibilities:
// - Serialize a byte with start, data and stop framing.
// - Hold off new bytes until the line is free.
// - Provide debug and trace output with deterministic timing.
//
// Characteristics:
// - Bit-serial state machine.
// - Baud timing is derived from the configured clock.
// - Uses explicit shift and bit counters.
//
// Design notes:
// - Keep baud divider and bit index named.
// =============================================================================
`default_nettype none

module chip8_uart_tx #(
  parameter int unsigned CLK_HZ = 27_000_000,
  parameter int unsigned BAUD   = 115_200
) (
  input  logic       clk_i,
  input  logic       rst_ni,
  input  logic       valid_i,
  output logic       ready_o,
  input  logic [7:0] data_i,
  output logic       tx_o
);

  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int unsigned UART_TX_DATA_BITS         = 8;
  localparam int unsigned UART_TX_STATE_WIDTH       = 2;
  localparam int unsigned UART_TX_DIV_COUNTER_WIDTH = 32;
  localparam int unsigned UART_TX_BIT_COUNTER_WIDTH = 3;

  localparam logic UART_TX_IDLE_LEVEL  = '1;
  localparam logic UART_TX_START_LEVEL = '0;
  localparam logic UART_TX_STOP_LEVEL  = '1;

  localparam int unsigned UART_TX_LSB_INDEX = 0;
  localparam int unsigned UART_TX_MSB_INDEX = UART_TX_DATA_BITS - 1;
  localparam int unsigned UART_TX_LAST_BIT  = UART_TX_DATA_BITS - 1;

  localparam int unsigned BAUD_DIV_RAW = CLK_HZ / BAUD;
  localparam int unsigned BAUD_DIV =
    (BAUD_DIV_RAW < 1) ? 1 : BAUD_DIV_RAW;

  // ------------------------------------------------------------
  // Type declarations
  // ------------------------------------------------------------

  // UART transmitter state machine.
  //
  // Responsibilities:
  // - Accept one byte only while idle.
  // - Serialize start, data and stop phases at the configured baud divider.
  // - Drive ready_o from the idle state.
  typedef enum logic [UART_TX_STATE_WIDTH-1:0] {
    UART_TX_STATE_IDLE,
    UART_TX_STATE_START,
    UART_TX_STATE_DATA,
    UART_TX_STATE_STOP
  } uart_tx_state_e;

  uart_tx_state_e state_q;
  uart_tx_state_e state_d;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [UART_TX_DIV_COUNTER_WIDTH-1:0] div_q;
  logic [UART_TX_DIV_COUNTER_WIDTH-1:0] div_d;
  logic [UART_TX_BIT_COUNTER_WIDTH-1:0] bit_q;
  logic [UART_TX_BIT_COUNTER_WIDTH-1:0] bit_d;
  logic [UART_TX_DATA_BITS-1:0]         shift_q;
  logic [UART_TX_DATA_BITS-1:0]         shift_d;
  logic                                 tx_q;
  logic                                 tx_d;
  logic                                 baud_done;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign ready_o = (state_q == UART_TX_STATE_IDLE);
  assign tx_o = tx_q;
  assign baud_done = div_q == UART_TX_DIV_COUNTER_WIDTH'(BAUD_DIV - 1);

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    state_d = state_q;
    div_d = div_q;
    bit_d = bit_q;
    shift_d = shift_q;
    tx_d = tx_q;

    unique case (state_q)
      UART_TX_STATE_IDLE: begin
        tx_d = UART_TX_IDLE_LEVEL;
        div_d = '0;
        bit_d = '0;

        if (valid_i) begin
          shift_d = data_i;
          state_d = UART_TX_STATE_START;
        end
      end

      UART_TX_STATE_START: begin
        tx_d = UART_TX_START_LEVEL;

        if (baud_done) begin
          div_d = '0;
          state_d = UART_TX_STATE_DATA;
        end else begin
          div_d = div_q + 1'b1;
        end
      end

      UART_TX_STATE_DATA: begin
        tx_d = shift_q[UART_TX_LSB_INDEX];

        if (baud_done) begin
          div_d = '0;
          shift_d = {UART_TX_START_LEVEL,
                 shift_q[UART_TX_MSB_INDEX:1]};

          if (bit_q ==
              UART_TX_BIT_COUNTER_WIDTH'(UART_TX_LAST_BIT)) begin
            bit_d = '0;
            state_d = UART_TX_STATE_STOP;
          end else begin
            bit_d = bit_q + 1'b1;
          end
        end else begin
          div_d = div_q + 1'b1;
        end
      end

      UART_TX_STATE_STOP: begin
        tx_d = UART_TX_STOP_LEVEL;

        if (baud_done) begin
          div_d = '0;
          state_d = UART_TX_STATE_IDLE;
        end else begin
          div_d = div_q + 1'b1;
        end
      end

      default: begin
        state_d = UART_TX_STATE_IDLE;
        div_d = '0;
        bit_d = '0;
        shift_d = '0;
        tx_d = UART_TX_IDLE_LEVEL;
      end
    endcase
  end

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      state_q <= UART_TX_STATE_IDLE;
      div_q   <= '0;
      bit_q   <= '0;
      shift_q <= '0;
      tx_q    <= UART_TX_IDLE_LEVEL;
    end else begin
      state_q <= state_d;
      div_q   <= div_d;
      bit_q   <= bit_d;
      shift_q <= shift_d;
      tx_q    <= tx_d;
    end
  end

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      assert(
        (state_q == UART_TX_STATE_IDLE) ||
        (state_q == UART_TX_STATE_START) ||
        (state_q == UART_TX_STATE_DATA) ||
        (state_q == UART_TX_STATE_STOP)
      );
    end
  end
`endif

endmodule

`default_nettype wire

// EOF
