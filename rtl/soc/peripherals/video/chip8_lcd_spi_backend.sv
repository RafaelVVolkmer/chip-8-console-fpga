// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_lcd_spi_backend.sv
// -----------------------------------------------------------------------------
// @brief LCD SPI scanout backend.
// =============================================================================
//
// Responsibilities:
// - Serialize monochrome pixels into SPI panel words.
// - Hold busy while a frame transfer is active.
// - Keep bit shifting and frame boundaries visible.
//
// Characteristics:
// - Bit-serial video adapter.
// - Converts one CHIP-8 pixel into an RGB565 word.
// - Uses explicit SPI shift state and frame counters.
//
// Design notes:
// - Name the bit index and pixel word encoding.
// =============================================================================
`default_nettype none

module chip8_lcd_spi_backend #(
  parameter int CLK_DIV = 4
) (
  input  logic          clk_i,
  input  logic          rst_ni,
  input  logic          enable_i,
  input  logic          force_frame_i,
  input  logic          invert_i,
  input  logic [2047:0] framebuffer_i,
  output logic          spi_sck_o,
  output logic          spi_mosi_o,
  output logic          spi_dc_o,
  output logic          spi_cs_o,
  output logic          spi_rst_o,
  output logic          busy_o,
  output logic          frame_done_o,
  output logic          error_o
);
  // ------------------------------------------------------------
  // Type declarations
  // ------------------------------------------------------------

  // LCD SPI pixel serializer state.
  //
  // Responsibilities:
  // - Convert one monochrome CHIP-8 pixel into a 16-bit RGB565 word.
  // - Shift the high and low display bytes over the SPI-like LCD bus.
  // - Assert busy while a frame transfer is active.
  typedef enum logic [1:0] {
    CHIP8_LCD_SPI_BACKEND_STATE_IDLE,
    CHIP8_LCD_SPI_BACKEND_STATE_SHIFT_HI,
    CHIP8_LCD_SPI_BACKEND_STATE_SHIFT_LO
  } state_e;

  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int PIXELS = 64 * 32;
  localparam int unsigned LAST_PIXEL = PIXELS - 1;
  localparam int unsigned LAST_DIV = CLK_DIV - 1;
  localparam logic [3:0] LCD_SPI_FIRST_BIT = 4'd0;
  localparam logic [3:0] LCD_SPI_LAST_BIT = 4'd15;
  localparam logic [15:0] LCD_SPI_PIXEL_OFF = 16'h0000;
  localparam logic [15:0] LCD_SPI_PIXEL_ON = 16'hffff;

  state_e state_q;
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [31:0] pixel_idx_q;
  logic [3:0] bit_idx_q;
  logic [15:0] pixel_word_q;
  logic [31:0] div_q;
  logic tick_spi;
  logic mono_pixel;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign mono_pixel = framebuffer_i[pixel_idx_q] ^ invert_i;
  assign spi_rst_o  = rst_ni;
  assign spi_dc_o   = '1;
  assign error_o    = '0;
  assign busy_o     = (state_q != CHIP8_LCD_SPI_BACKEND_STATE_IDLE);
  assign tick_spi   = (div_q == LAST_DIV);

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : lcd_spi_backend_ff
    if (!rst_ni) begin
      state_q      <= CHIP8_LCD_SPI_BACKEND_STATE_IDLE;
      pixel_idx_q  <= '0;
      bit_idx_q    <= LCD_SPI_LAST_BIT;
      pixel_word_q <= '0;
      div_q        <= '0;
      spi_sck_o    <= '0;
      spi_mosi_o   <= '0;
      spi_cs_o     <= '1;
      frame_done_o <= '0;
    end else begin
      frame_done_o <= '0;
      if (!enable_i) begin
        state_q   <= CHIP8_LCD_SPI_BACKEND_STATE_IDLE;
        spi_cs_o  <= '1;
        spi_sck_o <= '0;
        div_q     <= '0;
      end else begin
        if (div_q == LAST_DIV) begin
          div_q <= '0;
        end else begin
          div_q <= div_q + 1'b1;
        end

        unique case (state_q)
          CHIP8_LCD_SPI_BACKEND_STATE_IDLE: begin
            spi_cs_o <= '1;
            if (force_frame_i) begin
              pixel_idx_q  <= '0;
              bit_idx_q    <= LCD_SPI_LAST_BIT;
              pixel_word_q <= mono_pixel ? LCD_SPI_PIXEL_ON :
                LCD_SPI_PIXEL_OFF;
              spi_cs_o     <= '0;
              state_q <=
                CHIP8_LCD_SPI_BACKEND_STATE_SHIFT_HI;
            end
          end

          CHIP8_LCD_SPI_BACKEND_STATE_SHIFT_HI,
          CHIP8_LCD_SPI_BACKEND_STATE_SHIFT_LO: begin
            if (tick_spi) begin
              spi_sck_o  <= ~spi_sck_o;
              spi_mosi_o <= pixel_word_q[bit_idx_q];
              if (spi_sck_o) begin
                if (bit_idx_q == LCD_SPI_FIRST_BIT) begin
                  bit_idx_q <= LCD_SPI_LAST_BIT;
                  if (pixel_idx_q == LAST_PIXEL) begin
                    pixel_idx_q  <= '0;
                    spi_cs_o     <= '1;
                    frame_done_o <= '1;
                    state_q <=
                      CHIP8_LCD_SPI_BACKEND_STATE_IDLE;
                  end else begin
                    pixel_idx_q  <= pixel_idx_q + 1'b1;
                    pixel_word_q <= mono_pixel ? LCD_SPI_PIXEL_ON :
                      LCD_SPI_PIXEL_OFF;
                  end
                end else begin
                  bit_idx_q <= bit_idx_q - 1'b1;
                end
              end
            end
          end

          default: state_q <= CHIP8_LCD_SPI_BACKEND_STATE_IDLE;
        endcase
      end
    end
  end
endmodule

`default_nettype wire

// EOF
