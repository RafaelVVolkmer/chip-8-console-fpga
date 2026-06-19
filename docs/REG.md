<!--
SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
SPDX-License-Identifier: GPL-3.0-only
-->

# CHIP-8 Console FPGA SoC Register Map

**Document:** `REG.md`
**Target RTL:** `chip-8-console-fpga`
**Scope:** AXI-Lite visible SoC register map, internal CHIP-8 memory map, peripheral register pages, IRQ source map, and subprocessor/control block register semantics.

This document describes the register-visible architecture of the CHIP-8 FPGA SoC as implemented by the current RTL. It is written in a datasheet-like style and should be treated as a software/firmware-facing map for drivers, board bring-up, simulation monitors, and validation tests.

---

## 1. Addressing Model

The AXI-facing SoC uses a 16-bit register address and 32-bit register data path.

| Property | Value |
|---|---:|
| AXI address width | 16 bits |
| AXI data width | 32 bits |
| AXI byte strobes | 4 bits |
| Region select | `addr[15:8]` |
| Local register offset | `addr[7:0]` |
| Region size | `0x100` bytes per peripheral |
| Unmapped read value | `0xDEAD_0001` at interconnect level |

The AXI-Lite front-end captures AW/W independently through skid buffers, joins write address/data before emitting a register request, and returns read data through the register response path. This keeps the AXI-Lite edge decoupled while preserving deterministic single-register request semantics.

---

## 2. Top-Level AXI-Lite Peripheral Map

The high address byte selects the target peripheral. The low byte is passed to the selected block as the local register offset.

| Address range | Slave ID | Peripheral | Function |
|---:|---:|---|---|
| `0x1000–0x10FF` | `0x10` | VIDEO | Video backend control: HDMI, LCD-SPI, LCD-RGB, scaling, refresh, test pattern, video IRQs |
| `0x1100–0x11FF` | `0x11` | KEYPAD | 4×4 keypad accelerator, debounced key bitmap, key event FIFO/DMA, keypad IRQs |
| `0x1200–0x12FF` | `0x12` | DMA | Shared DMA/status block for keypad/video DMA completion and error status |
| `0x1300–0x13FF` | `0x13` | IRQ | SoC interrupt controller: pending, enable, status, clear |
| `0x1400–0x14FF` | `0x14` | DEBUG | SoC/core debug status window |
| `0x1500–0x15FF` | `0x15` | SD | SD/SPI host control and status for boot-image streaming |
| `0x1600–0x16FF` | `0x16` | BOOT | Bootloader controller: SD boot request, ROM load stream, core release, boot status |
| `0x1700–0x17FF` | `0x17` | UART | USB/UART debug/log path region; top-level allocation exists, register implementation depends on `chip8_uart_debug` availability |
| `0x1800–0x18FF` | `0x18` | DMA2D | 2D framebuffer engine: snapshot, clear, fill rectangle, invert, overlay framebuffer |
| `0x1900–0x19FF` | `0x19` | DCMIPP | Camera/display post-processing pipeline: invert, grid, freeze, luma capture, hash, frame counter |

---

## 3. Internal CHIP-8 Memory Map

This is the memory map inside the CHIP-8 core address space, not the AXI-Lite SoC register space.

| Range | Name | Description |
|---:|---|---|
| `0x000–0x04F` | Font ROM area | Built-in CHIP-8 font sprite storage range |
| `0x050–0x1FF` | Reserved/interpreter area | Reserved by convention; not used as ROM base |
| `0x200–0xFFF` | Program/RAM area | CHIP-8 ROM load base and writable RAM space |
| `0xFFF` | RAM last byte | 12-bit memory address upper bound |

The core PC resets to the CHIP-8 ROM base. ROM loader traffic writes into the 12-bit memory space using an external offset/data handshake.

---

## 4. Register Access Conventions

| Convention | Meaning |
|---|---|
| `RW` | Read/write register |
| `RO` | Read-only register |
| `WO` | Write-only command register |
| `W1C` | Write-one-to-clear status bits |
| `W1P` | Write-one pulse; self-clearing command bit |
| `sticky` | Latched until explicitly cleared |
| `local offset` | Offset inside the selected `0xXX00–0xXXFF` page |

Unless otherwise stated, unused/reserved bits read as zero and should be written as zero.

---

# 5. VIDEO Register Page — `0x1000–0x10FF`

The video remote core consumes the CHIP-8 64×32 one-bit framebuffer and drives one of three output backends:

- HDMI
- LCD over SPI
- LCD RGB parallel

It also supports inversion, force refresh, a test pattern, scaling, status flags, and video IRQ generation.

## 5.1 Register Summary

| Absolute address | Offset | Name | Access | Reset/default | Description |
|---:|---:|---|---|---:|---|
| `0x1000` | `0x00` | `VIDEO_CTRL` | RW | `enable=1` | Main video control |
| `0x1004` | `0x04` | `VIDEO_STATUS` | RO/W1C via `0x24` | `0x0000_0000` | Video status flags |
| `0x1008` | `0x08` | `VIDEO_BACKEND` | RW | parameter `DEFAULT_BACKEND` | Select active video backend |
| `0x100C` | `0x0C` | `VIDEO_SCALE` | RW | `10` | Pixel scale factor |
| `0x1020` | `0x20` | `VIDEO_IRQ_ENABLE` | RW | `0x0000_000E` | Enables video IRQ events |
| `0x1024` | `0x24` | `VIDEO_IRQ_CLEAR` | WO/W1C | — | Clears sticky video status bits |

## 5.2 `VIDEO_CTRL` — `0x1000`

| Bit(s) | Name | Access | Description |
|---:|---|---|---|
| `[0]` | `ENABLE` | RW | Enables video output and video DMA reader/backend activity |
| `[1]` | `FORCE_REFRESH` | RW/W1P | Requests a frame refresh; automatically clears after one cycle |
| `[2]` | `INVERT` | RW | Inverts output pixels |
| `[3]` | `TEST_PATTERN` | RW | Replaces framebuffer with built-in test pattern |
| `[31:4]` | Reserved | RO | Reads zero |

## 5.3 `VIDEO_STATUS` — `0x1004`

| Bit(s) | Name | Access | Description |
|---:|---|---|---|
| `[0]` | `ENABLE_STATUS` | RO | Mirrors current enable state |
| `[1]` | `FRAME_DONE` | RO/sticky | Set when HDMI/SPI/RGB backend completes a frame |
| `[2]` | `VBLANK` | RO/live | Current vblank from HDMI or LCD RGB backend |
| `[3]` | `ERROR` | RO/sticky | Set on SPI/backend error |
| `[31:4]` | Reserved | RO | Reads zero |

Clear sticky bits by writing a one mask to `VIDEO_IRQ_CLEAR`.

## 5.4 `VIDEO_BACKEND` — `0x1008`

| Value | Backend |
|---:|---|
| `0` | HDMI |
| `1` | LCD-SPI |
| `2` | LCD-RGB |
| `3` | Reserved |

## 5.5 `VIDEO_SCALE` — `0x100C`

| Bit(s) | Name | Access | Description |
|---:|---|---|---|
| `[7:0]` | `SCALE` | RW | Backend pixel scaling factor |
| `[31:8]` | Reserved | RO | Reads zero |

## 5.6 `VIDEO_IRQ_ENABLE` — `0x1020`

| Bit(s) | Name | Description |
|---:|---|---|
| `[1]` | `FRAME_DONE_EN` | Enables frame-done IRQ |
| `[2]` | `VBLANK_EN` | Enables vblank IRQ |
| `[3]` | `ERROR_EN` | Enables video error IRQ |
| Other | Reserved | Keep zero |

## 5.7 `VIDEO_IRQ_CLEAR` — `0x1024`

Write one bits to clear matching sticky bits in `VIDEO_STATUS`.

---

# 6. KEYPAD Register Page — `0x1100–0x11FF`

The keypad subprocessor scans a 4×4 matrix, debounces the input, generates a stable 16-bit key bitmap, tracks the last changed key, pushes event payloads into a FIFO-like DMA path, and exposes event/overflow IRQs.

## 6.1 Register Summary

| Absolute address | Offset | Name | Access | Reset/default | Description |
|---:|---:|---|---|---:|---|
| `0x1100` | `0x00` | `KEYPAD_CTRL` | RW | `0x0000_0007` | Enable, scan enable, IRQ enable |
| `0x1104` | `0x04` | `KEYPAD_STATUS` | RO | dynamic | FIFO and key-valid status |
| `0x1108` | `0x08` | `KEYPAD_BITMAP` | RO | dynamic | Current debounced 16-key bitmap |
| `0x110C` | `0x0C` | `KEYPAD_LAST_KEY` | RO | dynamic | Last changed key code |
| `0x1110` | `0x10` | `KEYPAD_FIFO_DATA` | RO/pop | dynamic | Reads event data and pops FIFO if non-empty |

## 6.2 `KEYPAD_CTRL` — `0x1100`

| Bit(s) | Name | Access | Description |
|---:|---|---|---|
| `[0]` | `ENABLE` | RW | Enables keypad remote core |
| `[1]` | `SCAN_ENABLE` | RW | Enables matrix scan engine |
| `[2]` | `IRQ_ENABLE` | RW | Enables event IRQ generation |
| `[31:3]` | Reserved | RO | Reads zero |

## 6.3 `KEYPAD_STATUS` — `0x1104`

| Bit(s) | Name | Access | Description |
|---:|---|---|---|
| `[2]` | `KEY_VALID` | RO | At least one debounced key is currently pressed |
| `[3]` | `FIFO_EMPTY` | RO | Key event FIFO is empty |
| `[4]` | `FIFO_FULL` | RO | Key event FIFO is full |
| `[5]` | `OVERFLOW` | RO/sticky source | Key event FIFO overflow occurred |
| Other | Reserved | RO | Reads zero |

## 6.4 `KEYPAD_BITMAP` — `0x1108`

| Bit(s) | Name | Access | Description |
|---:|---|---|---|
| `[15:0]` | `KEY_BITMAP` | RO | Debounced key state bitmap; one bit per CHIP-8 key |
| `[31:16]` | Reserved | RO | Reads zero |

## 6.5 `KEYPAD_LAST_KEY` — `0x110C`

| Bit(s) | Name | Access | Description |
|---:|---|---|---|
| `[3:0]` | `LAST_KEY` | RO | Last changed key index |
| `[31:4]` | Reserved | RO | Reads zero |

## 6.6 `KEYPAD_FIFO_DATA` — `0x1110`

Reading this register pops one event if the FIFO is not empty.

| Bit(s) | Name | Access | Description |
|---:|---|---|---|
| `[3:0]` | `KEY_CODE` | RO/pop | Key code associated with event |
| `[7:4]` | Reserved | RO | Reads zero |
| `[8]` | `RELEASED` | RO/pop | Key was released |
| `[9]` | `PRESSED` | RO/pop | Key was pressed |
| `[15:10]` | Reserved | RO | Reads zero |
| `[31:16]` | Reserved | RO | Reads zero |

---

# 7. DMA Register Page — `0x1200–0x12FF`

This block aggregates completion and error flags from keypad/video DMA paths.

## 7.1 Register Summary

| Absolute address | Offset | Name | Access | Reset/default | Description |
|---:|---:|---|---|---:|---|
| `0x1200` | `0x00` | `DMA_STATUS` | RO/W1C via `0x08` | `0x0000_0000` | Completion/error flags |
| `0x1204` | `0x04` | `DMA_ENABLE` | RW | `0x0000_0000` | Error interrupt enable mask |
| `0x1208` | `0x08` | `DMA_CLEAR` | WO/W1C | — | Clears status bits |

## 7.2 `DMA_STATUS` — `0x1200`

| Bit(s) | Name | Description |
|---:|---|---|
| `[0]` | `KEY_DMA_DONE` | Keypad DMA/event transfer completed |
| `[1]` | `VIDEO_DMA_DONE` | Video DMA/frame transfer completed |
| `[16]` | `KEY_DMA_OVERFLOW` | Keypad event FIFO/DMA overflow |
| `[17]` | `VIDEO_DMA_ERROR` | Video DMA/backend error |
| Other | Reserved | Reads zero |

`o_dma_error_irq` is asserted when any enabled error bit in `STATUS[31:16]` is set.

## 7.3 `DMA_ENABLE` — `0x1204`

| Bit(s) | Name | Description |
|---:|---|---|
| `[31:16]` | `ERROR_ENABLE_MASK` | Enables corresponding high-half status bits to produce DMA error IRQ |
| `[15:0]` | Completion mask/reserved | Present in register, currently not used by `o_dma_error_irq` |

## 7.4 `DMA_CLEAR` — `0x1208`

Write-one-to-clear mask for `DMA_STATUS`.

---

# 8. IRQ Register Page — `0x1300–0x13FF`

The IRQ controller latches SoC interrupt sources into a pending register. The output IRQ is the OR-reduction of `pending & enable`.

## 8.1 Register Summary

| Absolute address | Offset | Name | Access | Description |
|---:|---:|---|---|---|
| `0x1300` | `0x00` | `IRQ_PENDING` | RO/W1C via `0x0C` | Latched pending interrupt sources |
| `0x1304` | `0x04` | `IRQ_ENABLE` | RW | Interrupt enable mask |
| `0x1308` | `0x08` | `IRQ_STATUS` | RO | Bit 0 mirrors SoC IRQ output |
| `0x130C` | `0x0C` | `IRQ_CLEAR` | WO/W1C | Clears pending bits |

## 8.2 IRQ Source Bit Map

| Bit | Name | Source |
|---:|---|---|
| `0` | `IRQ_KEYPAD_EVENT` | Keypad key-change event |
| `1` | `IRQ_KEYPAD_OVERFLOW` | Keypad FIFO/event overflow |
| `2` | `IRQ_VIDEO_FRAME_DONE` | Video backend frame done |
| `3` | `IRQ_VIDEO_VBLANK` | Video vblank |
| `4` | `IRQ_VIDEO_ERROR` | Video/backend error |
| `5` | `IRQ_KEY_DMA_DONE` | Keypad DMA done |
| `6` | `IRQ_VIDEO_DMA_DONE` | Video DMA done |
| `7` | `IRQ_DMA_ERROR` | Aggregated DMA error |
| `8` | `IRQ_SD_DONE` | SD host boot read complete |
| `9` | `IRQ_SD_ERROR` | SD host boot read error |
| `10` | `IRQ_BOOT_DONE` | Bootloader released core after ROM load |
| `11` | `IRQ_BOOT_ERROR` | Bootloader error |
| `12` | `IRQ_UART_RX` | UART RX event |
| `13` | `IRQ_DMA2D_DONE` | DMA2D operation complete |
| `14` | `IRQ_DMA2D_ERROR` | DMA2D operation error |
| `15` | `IRQ_DCMIPP_FRAME` | DCMIPP/post-processing frame event |

---

# 9. DEBUG Register Page — `0x1400–0x14FF`

This page exposes core and SoC debug status. It is read-only in the current top-level decode.

## 9.1 Register Summary

| Absolute address | Offset | Name | Access | Description |
|---:|---:|---|---|---|
| `0x1400` | `0x00` | `DEBUG_STATUS0` | RO | Composite SoC status |
| `0x1404` | `0x04` | `DEBUG_CORE_STATUS` | RO | Core debug status register |
| `0x1424` | `0x24` | `DEBUG_SHCSR` | RO | Core debug/fault status window |
| `0x1428` | `0x28` | `DEBUG_CFSR` | RO | Core debug/fault status window |
| `0x142C` | `0x2C` | `DEBUG_HFSR` | RO | Core debug/fault status window |
| `0x1430` | `0x30` | `DEBUG_DFSR` | RO | Core debug/fault status window |
| `0x1434` | `0x34` | `DEBUG_MMFAR` | RO | Core debug/fault address/status window |
| `0x1438` | `0x38` | `DEBUG_BFAR` | RO | Core debug/fault address/status window |
| `0x143C` | `0x3C` | `DEBUG_AFSR` | RO | Core debug/fault auxiliary status |

## 9.2 `DEBUG_STATUS0` — `0x1400`

| Bit(s) | Name | Description |
|---:|---|---|
| `[2:0]` | `DCMIPP_PIXEL_X_LOW` | Low 3 bits of processed pixel X |
| `[5:3]` | `DCMIPP_PIXEL_Y_LOW` | Low 3 bits of processed pixel Y |
| `[17:6]` | `PC` | Current CHIP-8 program counter |
| `[21:18]` | `KEY_CODE` | Last/current keypad code |
| `[22]` | `CORE_HALTED` | Core halted/trapped state |
| `[23]` | `KEY_VALID` | Keypad key-valid status |
| `[24]` | `DCMIPP_PIXEL_VALID` | DCMIPP pixel-valid status |
| `[25]` | `CORE_RESET_N` | Effective core reset/release state |
| `[26]` | `SD_BOOT_BUSY` | SD boot path busy |
| `[27]` | `USB_LOG_VALID` | USB/UART boot log valid |
| `[31:28]` | Reserved | Reads zero |

---

# 10. SD Register Page — `0x1500–0x15FF`

The SD/SPI host performs a boot read from an SD-like SPI interface or a simulation boot ROM. It can be started by software or by the bootloader.

## 10.1 Register Summary

| Absolute address | Offset | Name | Access | Description |
|---:|---:|---|---|---|
| `0x1500` | `0x00` | `SD_CTRL` | WO/read-zero | Write bit 0 to start a software read |
| `0x1504` | `0x04` | `SD_STATUS` | RO | Busy/done/error status |
| `0x1508` | `0x08` | `SD_LBA` | RW | Logical block address |
| `0x150C` | `0x0C` | `SD_LENGTH` | RW | Number of bytes to stream |
| `0x1510` | `0x10` | `SD_BYTE_COUNT` | RO | Number of bytes streamed |
| `0x1514` | `0x14` | `SD_TIMEOUT` | RO | Timeout counter |
| `0x1518` | `0x18` | `SD_CRC16` | RO | Current CRC16 state |

## 10.2 `SD_STATUS` — `0x1504`

| Bit(s) | Name | Description |
|---:|---|---|
| `[5]` | `BUSY` | SD transfer in progress |
| `[6]` | `DONE` | SD transfer completed |
| `[7]` | `ERROR` | SD transfer failed |
| Other | Reserved | Reads zero |

---

# 11. BOOT Register Page — `0x1600–0x16FF`

The bootloader controls SD-to-ROM transfer and releases the CHIP-8 core after ROM load.

## 11.1 Register Summary

| Absolute address | Offset | Name | Access | Description |
|---:|---:|---|---|---|
| `0x1600` | `0x00` | `BOOT_CTRL` | RW/command | Enable bootloader, manual start, force core release |
| `0x1604` | `0x04` | `BOOT_STATUS` | RO | Boot state, released, busy, done, error |
| `0x1608` | `0x08` | `BOOT_LBA` | RW | SD boot LBA |
| `0x160C` | `0x0C` | `BOOT_LENGTH` | RW | Boot image length |
| `0x1610` | `0x10` | `BOOT_LOADED` | RO | Loaded byte count |

## 11.2 `BOOT_CTRL` — `0x1600`

| Bit(s) | Name | Access | Description |
|---:|---|---|---|
| `[0]` | `ENABLE` | RW | Enables automatic boot flow |
| `[1]` | `MANUAL_START` | WO/W1P | Starts or restarts boot flow |
| `[2]` | `FORCE_RELEASE` | WO/W1P | Forces the core release state |
| `[31:3]` | Reserved | RO | Reads zero |

Readback returns `{ released, 0, enable }` in bits `[2:0]`.

## 11.3 `BOOT_STATUS` — `0x1604`

| Bit(s) | Name | Description |
|---:|---|---|
| `[2:0]` | `STATE` | Bootloader FSM state |
| `[3]` | `RELEASED` | Core has been released from boot hold |
| `[4]` | `SD_BUSY` | SD boot path busy |
| `[5]` | `DONE` | Boot flow completed |
| `[6]` | `ERROR` | Boot flow failed |
| `[31:7]` | Reserved | Reads zero |

## 11.4 Boot FSM State Encoding

| Value | State | Description |
|---:|---|---|
| `0` | `RESET` | Reset/idle before boot sequence |
| `1` | `LOG_BOOT` | Emits `BOOT\n` log |
| `2` | `START_SD` | Starts SD read |
| `3` | `LOAD` | Streams SD bytes into CHIP-8 ROM loader |
| `4` | `LOG_RUN` | Emits `RUN\n` log |
| `5` | `RELEASE` | Releases core |
| `6` | `LOG_ERROR` | Emits `ERR\n` log |
| `7` | Reserved | Not used |

---

# 12. UART Register Page — `0x1700–0x17FF`

The SoC top-level allocates this region for the USB/UART debug/log block and wires it through the register interconnect. The top-level instantiates `chip8_uart_debug` with:

- UART TX/RX pins
- boot log input
- USB artifact output
- UART RX IRQ output
- register valid/write/address/data/strobe/readback handshake

However, the current source tree search exposed common UART TX/RX primitives but did not expose a register implementation file for `chip8_uart_debug`. Therefore, this register page is reserved in this document until the UART debug register block is added or its source is made visible.

| Absolute address range | Status | Intended function |
|---:|---|---|
| `0x1700–0x17FF` | Reserved/implementation-defined | USB/UART debug console, boot logs, RX interrupt, firmware debug path |

Recommended future register map:

| Offset | Name | Suggested access | Suggested function |
|---:|---|---|---|
| `0x00` | `UART_CTRL` | RW | Enable TX/RX, loopback, IRQ enable |
| `0x04` | `UART_STATUS` | RO/W1C | TX busy, RX valid, RX overflow |
| `0x08` | `UART_TXDATA` | WO | Write byte to transmit |
| `0x0C` | `UART_RXDATA` | RO/pop | Read received byte |
| `0x10` | `UART_BAUDDIV` | RW | Baud-rate divider |

---

# 13. DMA2D Register Page — `0x1800–0x18FF`

The DMA2D engine transforms the 64×32 framebuffer into an overlay framebuffer. It supports snapshot, clear, fill rectangle, and invert operations.

## 13.1 Operation Encoding

| Value | Operation | Description |
|---:|---|---|
| `0` | `SNAPSHOT` | Copy input framebuffer into DMA2D overlay RAM |
| `1` | `CLEAR` | Write all pixels to configured color |
| `2` | `FILL` | Fill configured rectangle with configured color |
| `3` | `INVERT` | Invert pixels |
| `4–7` | Passthrough/reserved | Current dataflow falls back to base pixel |

## 13.2 Register Summary

| Absolute address | Offset | Name | Access | Description |
|---:|---:|---|---|---|
| `0x1800` | `0x00` | `DMA2D_CTRL` | RW/command | Start operation, select op, clear overlay |
| `0x1804` | `0x04` | `DMA2D_STATUS` | RO | State, done, error |
| `0x1808` | `0x08` | `DMA2D_COLOR` | RW | One-bit drawing color |
| `0x180C` | `0x0C` | `DMA2D_COORD` | RW | Rectangle origin |
| `0x1810` | `0x10` | `DMA2D_SIZE` | RW | Rectangle width/height |
| `0x1814` | `0x14` | `DMA2D_INDEX` | RO | Current pixel index |

## 13.3 `DMA2D_CTRL` — `0x1800`

| Bit(s) | Name | Access | Description |
|---:|---|---|---|
| `[0]` | `START` | WO/W1P | Starts selected operation |
| `[3:1]` | `OP` | RW | Operation encoding |
| `[4]` | `OVERLAY_ENABLE` / `CLEAR_OVERLAY` | RO/WO | Read mirrors overlay enabled; write one clears overlay enable |
| `[31:5]` | Reserved | RO | Reads zero |

## 13.4 `DMA2D_STATUS` — `0x1804`

| Bit(s) | Name | Description |
|---:|---|---|
| `[1:0]` | `STATE` | `0=IDLE`, `1=RUN`, `2=DONE`, `3=ERROR` |
| `[2]` | `DONE` | Operation complete pulse/status |
| `[3]` | `ERROR` | Operation error pulse/status |
| `[31:4]` | Reserved | Reads zero |

## 13.5 `DMA2D_COORD` — `0x180C`

| Bit(s) | Name | Description |
|---:|---|---|
| `[5:0]` | `X` | Rectangle origin X |
| `[7:6]` | Reserved | Reads zero |
| `[12:8]` | `Y` | Rectangle origin Y |
| `[31:13]` | Reserved | Reads zero |

## 13.6 `DMA2D_SIZE` — `0x1810`

| Bit(s) | Name | Description |
|---:|---|---|
| `[6:0]` | `WIDTH` | Rectangle width |
| `[7]` | Reserved | Reads zero |
| `[13:8]` | `HEIGHT` | Rectangle height |
| `[31:14]` | Reserved | Reads zero |

A `FILL` operation with zero width or zero height enters the error state.

---

# 14. DCMIPP Register Page — `0x1900–0x19FF`

This block is a display/camera-processing stage inspired by camera/display pipelines. It can process the CHIP-8 framebuffer, apply grid/invert/freeze, capture a one-bit camera-derived framebuffer from luma samples, and expose frame counters/hash status.

## 14.1 Register Summary

| Absolute address | Offset | Name | Access | Description |
|---:|---:|---|---|---|
| `0x1900` | `0x00` | `DCMIPP_CTRL` | RW/command | Enable, invert, grid, freeze, snapshot freeze |
| `0x1904` | `0x04` | `DCMIPP_INDEX` | RO | Current processing index |
| `0x1908` | `0x08` | `DCMIPP_FRAME_COUNT` | RO | Processed frame count |
| `0x190C` | `0x0C` | `DCMIPP_PIXEL` | RO | Current processed pixel and coordinates |
| `0x1910` | `0x10` | `DCMIPP_FRAME_HASH` | RW | Rolling frame hash seed/readback |
| `0x1914` | `0x14` | `DCMIPP_CAPTURE_CTRL` | RW | Camera capture control |
| `0x1918` | `0x18` | `DCMIPP_CAPTURE_POS` | RO | Camera capture X/Y/phase |

## 14.2 `DCMIPP_CTRL` — `0x1900`

| Bit(s) | Name | Access | Description |
|---:|---|---|---|
| `[0]` | `ENABLE` | RW | Enables DCMIPP processing |
| `[1]` | `INVERT` | RW | Inverts processed framebuffer |
| `[2]` | `GRID` | RW | XORs border/grid mask into framebuffer |
| `[3]` | `FREEZE` | RW | Outputs frozen framebuffer instead of live source |
| `[4]` | `SNAPSHOT_FREEZE` | WO/W1P | Copies current source framebuffer into frozen buffer |
| `[31:5]` | Reserved | RO | Reads zero |

Readback includes bits `[3:0]`; bit 4 is a command-only bit.

## 14.3 `DCMIPP_PIXEL` — `0x190C`

| Bit(s) | Name | Description |
|---:|---|---|
| `[5:0]` | `PIXEL_X` | Current X |
| `[10:6]` | `PIXEL_Y` | Current Y |
| `[11]` | `PIXEL` | Current processed pixel |
| `[31:12]` | Reserved | Reads zero |

## 14.4 `DCMIPP_CAPTURE_CTRL` — `0x1914`

| Bit(s) | Name | Access | Description |
|---:|---|---|---|
| `[0]` | `CAPTURE_ENABLE` | RW | Enables camera capture |
| `[1]` | `CLEAR_CAMERA_FB` | WO/W1P | Clears captured camera framebuffer |
| `[3:2]` | `CAPTURE_FORMAT` | RW | `0=MONO_Y`, `1=YCBCR422`, others reserved |
| `[5:4]` | `SOURCE_SEL` | RW | `0=framebuffer`, `1=camera`, others reserved |
| `[7:6]` | Reserved | RO | Reads zero |
| `[15:8]` | `LUMA_THRESHOLD` | RW | Camera luma threshold; default `0x80` |
| `[31:16]` | Reserved | RO | Reads zero |

## 14.5 `DCMIPP_CAPTURE_POS` — `0x1918`

| Bit(s) | Name | Description |
|---:|---|---|
| `[5:0]` | `CAPTURE_X` | Camera capture X |
| `[10:6]` | `CAPTURE_Y` | Camera capture Y |
| `[12:11]` | `YCBCR_PHASE` | YCbCr sample phase |
| `[31:13]` | Reserved | Reads zero |

---

# 15. Subprocessor Summary

| Subprocessor/block | Register page | Main role |
|---|---:|---|
| Keypad remote core | `0x1100` | Matrix scan, debounce, key bitmap, event FIFO/DMA, key IRQs |
| Video remote core | `0x1000` | Framebuffer scanout to HDMI/LCD backends |
| DMA2D engine | `0x1800` | Full-frame or rectangle framebuffer transformations |
| DCMIPP pipeline | `0x1900` | Optional camera/luma capture and framebuffer post-processing |
| SD SPI host | `0x1500` | SD boot block read and byte streaming |
| Bootloader | `0x1600` | Boot FSM, ROM-load stream, core release, boot logs |
| IRQ controller | `0x1300` | IRQ latching, enable, clear, output OR reduction |
| Debug window | `0x1400` | PC/core/SOC observable debug state |
| UART debug | `0x1700` | Allocated debug/log page; implementation-defined until UART register source is visible |

---

# 16. Firmware Bring-Up Sequence Example

A typical boot/debug sequence can follow:

1. Configure SD LBA and length:
   - `SD_LBA = desired LBA`
   - `SD_LENGTH = ROM byte count`
2. Enable bootloader or write `BOOT_CTRL.MANUAL_START = 1`.
3. Poll `BOOT_STATUS.DONE` or enable `IRQ_BOOT_DONE`.
4. Verify `BOOT_STATUS.RELEASED = 1`.
5. Read `DEBUG_STATUS0.PC` to confirm the core is running near `0x200`.
6. Enable video backend through `VIDEO_CTRL` and select `VIDEO_BACKEND`.
7. Enable keypad IRQs through `KEYPAD_CTRL` and global `IRQ_ENABLE`.

---

# 17. Validation Checklist

For register-level validation, add tests for:

- Unmapped address returns `0xDEAD_0001`.
- Every slave page responds with `ready`.
- Reserved bits read zero.
- W1C registers clear only selected bits.
- IRQ pending latches source pulses and clears via `IRQ_CLEAR`.
- Video `FORCE_REFRESH` self-clears.
- Keypad FIFO read pops exactly one event.
- SD start transitions through busy/done/error status.
- Bootloader releases core only after ROM stream completes or force release is written.
- DMA2D invalid rectangle sets error for `FILL`.
- DCMIPP frame counter increments and frame hash changes as expected.

---

# 18. Source-of-Truth RTL Files

Primary files used to derive this map:

- `rtl/soc/bus/chip8_axi_pkg.sv`
- `rtl/soc/bus/chip8_reg_interconnect.sv`
- `rtl/soc/bus/chip8_axi_lite_to_reg.sv`
- `rtl/core/chip8/pkg/chip8_memmap_pkg.sv`
- `rtl/soc/peripherals/video/chip8_video_regs.sv`
- `rtl/soc/peripherals/video/chip8_video_remote_core.sv`
- `rtl/soc/peripherals/video/chip8_dma2d_engine.sv`
- `rtl/soc/peripherals/video/chip8_dcmipp_pipeline.sv`
- `rtl/soc/peripherals/keypad/chip8_keypad_regs.sv`
- `rtl/soc/peripherals/keypad/chip8_keypad_remote_core.sv`
- `rtl/soc/dma/chip8_dma_regs.sv`
- `rtl/soc/irq/chip8_irq_controller.sv`
- `rtl/soc/storage/chip8_sd_spi_host.sv`
- `rtl/soc/storage/chip8_bootloader.sv`
- `rtl/soc/chip8_axi_soc.sv`

<!-- EOF -->
