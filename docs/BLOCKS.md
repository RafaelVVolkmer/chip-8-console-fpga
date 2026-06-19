<!--
SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
SPDX-License-Identifier: GPL-3.0-only
-->

# CHIP-8 Console FPGA — RTL Block Catalog

This file is a file-by-file architectural catalog for the RTL tree. It complements `ARCHITECTURE.md` by assigning each source file a role, layer and integration meaning.

---

## 1. Board layer

| Path | Layer | Role |
|---|---|---|
| `rtl/boards/common/chip8_usb_soc_top.sv` | Board/common | Common USB/debug-facing SoC wrapper. |
| `rtl/boards/tang_nano_9k/tang_nano_9k_top.sv` | Board/Tang Nano | Tang Nano 9K physical top. |
| `rtl/boards/tang_nano_9k/tang_nano_9k_clock_reset.sv` | Board/Tang Nano | Clock/reset adaptation for Tang Nano 9K. |
| `rtl/boards/artix_a7/artix_a7_top.sv` | Board/Artix | Artix-7 physical top. |
| `rtl/boards/artix_a7/artix_a7_pkg.sv` | Board/Artix | Artix-7 constants/package. |
| `rtl/boards/cyclone_v/cyclone_v_top.sv` | Board/Cyclone | Cyclone V physical top. |
| `rtl/boards/cyclone_v/cyclone_v_pkg.sv` | Board/Cyclone | Cyclone V constants/package. |
| `rtl/boards/custom_usb_fpga/custom_usb_fpga_top.sv` | Board/custom | Custom USB FPGA physical top. |

---

## 2. Common library layer

| Path | Block type | Role | Connected to |
|---|---|---|---|
| `rtl/lib/common/cdc/chip8_sync_2ff.sv` | CDC | 2FF synchronizer for async signals. | key/control/reset/event crossings |
| `rtl/lib/common/cdc/chip8_pulse_sync.sv` | CDC | pulse-to-toggle-to-pulse synchronizer. | cross-clock one-shot events |
| `rtl/lib/common/cdc/chip8_async_fifo.sv` | CDC/FIFO | Gray-pointer async FIFO for multi-bit payloads. | future/debug/event payload CDC |
| `rtl/lib/common/fifo/chip8_sync_fifo.sv` | FIFO | same-clock event/data queue with overflow. | keypad DMA/event queues, debug queues |
| `rtl/lib/common/fifo/chip8_skid_buffer.sv` | Elasticity | single-entry ready/valid stage. | AXI-Lite bridge AW/W/AR |
| `rtl/lib/common/reset/chip8_reset_controller.sv` | Reset | reset aggregation and synchronized release. | board/SoC/core/video/debug/storage reset |
| `rtl/lib/common/reduction/chip8_prefix_count.sv` | Reduction | predicate/popcount-style reduction. | vector/status/event summaries |
| `rtl/lib/common/crc/chip8_crc16_ccitt.sv` | CRC | reusable CRC16-CCITT primitive. | storage/checking paths |
| `rtl/lib/common/uart/chip8_uart_tx.sv` | UART | byte TX FSM with baud divider. | debug/log serial path |
| `rtl/lib/common/uart/chip8_uart_rx.sv` | UART | byte RX FSM/sampling path. | debug command serial path |

---

## 3. CHIP-8 core packages

| Path | Role |
|---|---|
| `rtl/core/chip8/pkg/chip8_pkg.sv` | Common CHIP-8 package. |
| `rtl/core/chip8/pkg/chip8_config_pkg.sv` | Frequency/timer/config constants. |
| `rtl/core/chip8/pkg/chip8_types_pkg.sv` | Shared packed types. |
| `rtl/core/chip8/pkg/chip8_isa_pkg.sv` | Opcode class enum. |
| `rtl/core/chip8/pkg/chip8_core_pkg.sv` | CPU state, op, uop, decoded struct, illegal policy. |
| `rtl/core/chip8/pkg/chip8_alu_pkg.sv` | ALU op enum. |
| `rtl/core/chip8/pkg/chip8_mem_pkg.sv` | Memory constants/types. |
| `rtl/core/chip8/pkg/chip8_memmap_pkg.sv` | Internal memory map: font, ROM base, RAM last. |
| `rtl/core/chip8/pkg/chip8_display_pkg.sv` | Display geometry constants. |
| `rtl/core/chip8/pkg/chip8_periph_pkg.sv` | Core peripheral constants. |

---

## 4. CHIP-8 CPU and internal core blocks

| Path | Role |
|---|---|
| `rtl/core/chip8/cpu/chip8_core.sv` | CPU/core integration: FSM, registers, memory, display, timers, keypad, debug. |
| `rtl/core/chip8/cpu/chip8_fetch.sv` | Opcode fetch and assembly support. |
| `rtl/core/chip8/cpu/chip8_prefetch_queue.sv` | Sequential opcode prefetch queue. |
| `rtl/core/chip8/cpu/chip8_decode.sv` | Opcode field extraction, legality and resource decode. |
| `rtl/core/chip8/cpu/chip8_control.sv` | Control/resource classification. |
| `rtl/core/chip8/cpu/chip8_execute.sv` | Conditional skip decision logic. |
| `rtl/core/chip8/cpu/chip8_datapath.sv` | PC/address/coordinate datapath calculations. |
| `rtl/core/chip8/cpu/chip8_pc.sv` | Program-counter helper logic. |
| `rtl/core/chip8/cpu/chip8_regfile.sv` | V0–VF register file. |
| `rtl/core/chip8/cpu/chip8_alu.sv` | CHIP-8 ALU and VF flag equations. |
| `rtl/core/chip8/cpu/chip8_stack.sv` | CALL/RET return stack. |
| `rtl/core/chip8/cpu/chip8_rng.sv` | Random byte generator for `Cxkk`. |
| `rtl/core/chip8/cpu/chip8_bcd.sv` | BCD digit generation. |
| `rtl/core/chip8/cpu/chip8_bcd_writer.sv` | Multi-cycle BCD memory writer. |
| `rtl/core/chip8/cpu/chip8_draw_sequencer.sv` | Draw row/bit sequence control. |
| `rtl/core/chip8/cpu/chip8_mem_burst.sv` | `Fx55`/`Fx65` register burst sequencer. |
| `rtl/core/chip8/cpu/chip8_trace.sv` | Trace/debug observation support. |

---

## 5. Core memory, video, input, timers and bus

| Path | Role |
|---|---|
| `rtl/core/chip8/memory/chip8_memory.sv` | Core memory wrapper. |
| `rtl/core/chip8/memory/chip8_ram.sv` | RAM implementation. |
| `rtl/core/chip8/memory/chip8_mem_arbiter.sv` | CPU/ROM-loader write arbitration. |
| `rtl/core/chip8/memory/chip8_rom_loader.sv` | ROM byte write stream into memory. |
| `rtl/core/chip8/video/chip8_framebuffer.sv` | 64×32 1-bit framebuffer storage. |
| `rtl/core/chip8/video/chip8_display_controller.sv` | clear/draw/scan display control. |
| `rtl/core/chip8/video/chip8_sprite_blitter.sv` | sprite bit-to-coordinate generation. |
| `rtl/core/chip8/video/chip8_collision_unit.sv` | collision detection for VF. |
| `rtl/core/chip8/input/chip8_keypad.sv` | core keypad access. |
| `rtl/core/chip8/input/chip8_key_sync.sv` | key synchronization. |
| `rtl/core/chip8/input/chip8_key_debounce.sv` | key debounce. |
| `rtl/core/chip8/input/chip8_wait_key_unit.sv` | `Fx0A` wait-key support. |
| `rtl/core/chip8/timers/chip8_timer.sv` | delay/sound timer. |
| `rtl/core/chip8/timers/chip8_timer_60hz.sv` | 60 Hz tick generation. |
| `rtl/core/chip8/bus/chip8_bus.sv` | core-local bus abstraction. |
| `rtl/core/chip8/bus/chip8_io_mux.sv` | timer/keypad/debug read mux for core operations. |
| `rtl/core/chip8/top/chip8_core_top.sv` | core/native top wrapper. |
| `rtl/core/chip8/top/chip8_fpga_top.sv` | FPGA-friendly top integration. |

---

## 6. SoC-level blocks

| Path | Role |
|---|---|
| `rtl/soc/chip8_native_soc.sv` | minimal SoC wrapping key sync/debounce and `chip8_core`. |
| `rtl/soc/chip8_axi_soc.sv` | full AXI/MMIO SoC integration. |
| `rtl/soc/bus/chip8_axi_pkg.sv` | AXI widths, page IDs, backend IDs, IRQ IDs. |
| `rtl/soc/bus/chip8_axi_lite_to_reg.sv` | AXI-Lite to internal register bridge. |
| `rtl/soc/bus/chip8_reg_interconnect.sv` | MMIO page decoder and read-data mux. |
| `rtl/soc/dma/chip8_dma_pkg.sv` | DMA package. |
| `rtl/soc/dma/chip8_dma_regs.sv` | DMA status/enable/clear register block. |
| `rtl/soc/dma/chip8_keypad_dma.sv` | keypad event FIFO/DMA. |
| `rtl/soc/dma/chip8_video_dma_reader.sv` | video/frame scan DMA reader. |
| `rtl/soc/irq/chip8_irq_controller.sv` | pending/enable/clear interrupt controller. |
| `rtl/soc/storage/chip8_bootloader.sv` | SD-to-ROM boot FSM and core release. |
| `rtl/soc/storage/chip8_sd_spi_host.sv` | SD/SPI read host with data stream and CRC tracking. |
| `rtl/soc/storage/chip8_sd_crc.sv` | SD CRC helpers. |
| `rtl/soc/storage/boot/chip8_rom_load_arbiter.sv` | boot/program/external ROM source arbiter. |
| `rtl/soc/storage/boot/chip8_rom_chunk_writer.sv` | chunked ROM stream writer. |

---

## 7. SoC peripheral subprocessors

| Path | Subsystem | Role |
|---|---|---|
| `rtl/soc/peripherals/keypad/chip8_keypad_accel.sv` | Keypad | accelerator wrapper. |
| `rtl/soc/peripherals/keypad/chip8_keypad_remote_core.sv` | Keypad | matrix scan + debounce + event detect + DMA + regs. |
| `rtl/soc/peripherals/keypad/chip8_keypad_matrix_4x4.sv` | Keypad | physical row/column scanner. |
| `rtl/soc/peripherals/keypad/chip8_keypad_regs.sv` | Keypad | MMIO control/status/FIFO pop. |
| `rtl/soc/peripherals/video/chip8_video_accel.sv` | Video | video accelerator wrapper. |
| `rtl/soc/peripherals/video/chip8_video_remote_core.sv` | Video | backend selection, DMA reader, HDMI/LCD fanout. |
| `rtl/soc/peripherals/video/chip8_video_regs.sv` | Video | MMIO control/status/IRQ. |
| `rtl/soc/peripherals/video/chip8_video_scaler.sv` | Video | pixel scaling support. |
| `rtl/soc/peripherals/video/chip8_video_dma_reader.sv` | Video | framebuffer pixel stream generation. |
| `rtl/soc/peripherals/video/chip8_dma2d_engine.sv` | DMA2D | snapshot/clear/fill/invert full-frame engine. |
| `rtl/soc/peripherals/video/chip8_dcmipp_pipeline.sv` | DCMIPP | invert/grid/freeze/capture/hash postprocess. |
| `rtl/soc/peripherals/video/chip8_hdmi_backend.sv` | HDMI | HDMI physical/backend output. |
| `rtl/soc/peripherals/video/chip8_lcd_spi_backend.sv` | LCD SPI | SPI LCD backend output. |
| `rtl/soc/peripherals/video/chip8_lcd_rgb_backend.sv` | LCD RGB | parallel RGB LCD backend output. |
