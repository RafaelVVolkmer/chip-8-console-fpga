<!--
SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
SPDX-License-Identifier: GPL-3.0-only
-->

# CHIP-8 Console FPGA — Complete Connected RTL/SoC Technical Architecture

**Repository:** `RafaelVVolkmer/chip-8-console-fpga`
**Primary RTL scope:** complete `rtl/` tree: boards, CHIP-8 core, native SoC, AXI/MMIO SoC, storage, DMA, video, keypad, IRQ/debug, and reusable common library.
**Companion documents:**

- [`REG.md`](./REG.md): AXI-Lite register map and datasheet-style peripheral programming model.
- [`ISA.md`](./ISA.md): CHIP-8 instruction set implemented by the current CPU RTL.
- [`BLOCKS.md`](./BLOCKS.md): file-by-file block catalog and integration role.
- [`TECHNICAL_NOTES.md`](./TECHNICAL_NOTES.md): RTL techniques, process notes, verification expectations and design references.
- [`VERIFICATION.md`](./VERIFICATION.md): validation strategy, coverage map, CI flows and sign-off commands.

This document is written as the architectural entry point for the repository. It describes not only the CHIP-8 CPU core, but also all connected SoC subsystems and the common RTL infrastructure that makes the design portable, timing-friendly and verifiable.

The architecture deliberately follows reviewable digital-design patterns: explicit clock/reset ownership, ready/valid transfer boundaries, skid buffers on register ingress, 2FF/pulse/FIFO CDC primitives, bounded formal checks for local invariants, Verilator simulation for behavioral regression and Yosys/SBY checks for synthesizability and formal reachability.

---

## 1. Architectural goal

The project is a small FPGA-based CHIP-8 console implemented as a synthesizable SystemVerilog SoC. The design is intentionally split into reusable layers:

```text
Board wrapper
  -> clock/reset adaptation
  -> SoC shell
  -> AXI-Lite / MMIO control plane
  -> native CHIP-8 compute/display/input core
  -> storage boot path
  -> keypad subprocessor
  -> DMA / DMA2D / video processing subprocessors
  -> display backends
  -> IRQ/debug/UART paths
  -> reusable RTL library primitives
```

The SoC is therefore not just an interpreter core. It is a complete RTL platform organized around:

- a CHIP-8 in-order multi-cycle CPU;
- a 4 KiB CHIP-8 memory subsystem with ROM loading;
- a 64×32 one-bit framebuffer;
- display acceleration and scanout backends;
- keypad matrix scanning, debounce, FIFO/event and IRQ support;
- SD/SPI boot streaming into program memory;
- AXI-Lite software-visible control/status registers;
- reset, CDC, FIFO, skid-buffer, reduction, CRC and UART support blocks.

---

## 2. Connected top-level system view

```text
                         +-------------------------------+
                         |            Board top           |
                         | Tang Nano / Artix / Cyclone V |
                         +---------------+---------------+
                                         |
                                         v
                         +-------------------------------+
                         | clock/reset / board IO adapter |
                         +---------------+---------------+
                                         |
                                         v
+-------------+      +-------------------+-------------------+      +-------------+
| AXI-Lite    | ---> | chip8_axi_lite_to_reg + reg xbar       | ---> | MMIO pages  |
| controller  |      | pages: 10 VIDEO ... 19 DCMIPP          |      | REG.md      |
+-------------+      +-------------------+-------------------+      +-------------+
                                         |
                                         v
       +----------------------+   +---------------------+   +----------------------+
       | SD/SPI host          |-->| bootloader          |-->| ROM load arbiter     |
       | boot image stream    |   | core hold/release   |   | ext/prog/boot select |
       +----------------------+   +---------------------+   +----------+-----------+
                                                                    |
                                                                    v
+----------------------+     +---------------------+       +----------------------+
| keypad accelerator   |---->| native CHIP-8 SoC   |------>| core framebuffer     |
| matrix/debounce/FIFO |     | CPU/mem/timer/video |       +----------+-----------+
+----------+-----------+     +----------+----------+                  |
           |                            |                             v
           v                            v                 +----------------------+
    IRQ sources                 debug/status              | DMA2D framebuffer    |
           |                            |                 +----------+-----------+
           v                            |                            |
+----------+-----------+                |                            v
| IRQ controller       |<---------------+                 +----------------------+
| pending/enable/clear |                                  | DCMIPP/postprocess   |
+----------+-----------+                                  +----------+-----------+
           |                                                        |
           v                                                        v
         o_irq                                           +----------------------+
                                                         | video accelerator    |
                                                         | HDMI / LCD SPI / RGB |
                                                         +----------------------+
```

---

## 3. Complete RTL tree and responsibilities

```text
rtl/
├── boards/
│   ├── common/chip8_usb_soc_top.sv
│   ├── tang_nano_9k/tang_nano_9k_top.sv
│   ├── tang_nano_9k/tang_nano_9k_clock_reset.sv
│   ├── artix_a7/artix_a7_top.sv
│   ├── artix_a7/artix_a7_pkg.sv
│   ├── cyclone_v/cyclone_v_top.sv
│   ├── cyclone_v/cyclone_v_pkg.sv
│   └── custom_usb_fpga/custom_usb_fpga_top.sv
│
├── core/chip8/
│   ├── pkg/                 ISA, core state, config, memory/display/peripheral constants
│   ├── if/                  bus/debug/video/keypad interface contracts
│   ├── cpu/                 fetch, prefetch, decode, control, execute, datapath, ALU, stack, RNG, BCD, draw, bursts
│   ├── memory/              4 KiB memory, RAM, arbiter, ROM loader
│   ├── video/               framebuffer, display controller, sprite blitter, collision
│   ├── input/               key sync, debounce, keypad selection, wait-key
│   ├── timers/              delay/sound timers and 60 Hz tick generation
│   ├── bus/                 core-local bus and IO mux
│   └── top/                 core top and FPGA-friendly wrapper
│
├── soc/
│   ├── chip8_native_soc.sv  minimal SoC around CHIP-8 core
│   ├── chip8_axi_soc.sv     full AXI/MMIO SoC integration
│   ├── bus/                 AXI package, AXI-Lite bridge, register interconnect
│   ├── dma/                 DMA status, keypad DMA, video DMA reader, DMA package
│   ├── irq/                 interrupt controller
│   ├── storage/             bootloader, SD/SPI host, SD CRC, ROM load arbiter, ROM chunk writer
│   └── peripherals/
│       ├── keypad/          remote keypad subprocessor, matrix scanner, regs, accelerator
│       └── video/           video accelerator, regs, scaler, DMA2D, DCMIPP, HDMI/LCD backends
│
└── lib/common/
    ├── cdc/                 2FF synchronizer, pulse synchronizer, async FIFO
    ├── fifo/                sync FIFO, skid buffer
    ├── reset/               reset controller
    ├── reduction/           prefix/predicate counter
    ├── crc/                 CRC16-CCITT primitive
    └── uart/                UART TX/RX primitives
```

The `lib/common` layer is an architectural dependency. It is not miscellaneous utility code. It provides the CDC, buffering, reset and datapath primitives needed by the SoC control plane and board integration.

---

## 4. Layer A — board and physical integration

### 4.1 Board wrappers

Board wrappers adapt the generic SoC to physical FPGA boards. They should own pinout, PLL/clock naming, reset input polarity and board-specific IO. The portable SoC should not contain Tang Nano, Artix or Cyclone-specific assumptions.

| Area | Role |
|---|---|
| `boards/common` | common USB/SoC wrapper for shared debug/log/pin adaptation |
| `boards/tang_nano_9k` | Gowin Tang Nano 9K top, HDMI/LCD/SD/keypad/USB-style board IO, clock/reset adapter |
| `boards/artix_a7` | Xilinx Artix-7 top and package constants |
| `boards/cyclone_v` | Intel/Altera Cyclone V top and package constants |
| `boards/custom_usb_fpga` | custom USB FPGA board top |

### 4.2 Clock/reset responsibility

The board layer should feed clean reset into the SoC. The common reset controller combines external reset, PLL lock, DAP reset, watchdog reset and fatal-error reset into synchronized reset outputs for SoC, CPU, video, debug and storage domains.

---

## 5. Layer B — common library infrastructure

### 5.1 CDC primitives

#### `chip8_sync_2ff.sv`

Parameterized two-flop synchronizer. It samples an asynchronous input into a destination clock domain through two sequential registers and emits a synchronized output. It is intended for single-bit or carefully encoded multi-bit signals. It uses `sync0_q` and `sync1_q`, and resets both to a configurable level.

Use cases:

- external key or control input synchronization;
- async status flag capture;
- safe reset/control handoff when no payload bus is involved.

#### `chip8_pulse_sync.sv`

Pulse synchronizer based on a source-domain toggle, a 2FF synchronizer in the destination domain and an edge detector. It converts a source pulse into a destination pulse even when the destination clock cannot see the original pulse width.

Use cases:

- IRQ/event pulse crossing;
- debug/event kick between domains;
- one-shot command handoff.

#### `chip8_async_fifo.sv`

Asynchronous FIFO for multi-bit payload crossing. It uses binary pointers locally, Gray-coded pointers across domains, synchronized opposite-domain pointers and full/empty detection. It is the correct primitive when the payload is wider than a single event bit and must not be sampled incoherently.

Use cases:

- UART/USB/debug payload crossings;
- event stream crossing;
- future video/SD buffering across clocks.

### 5.2 FIFO and elasticity

#### `chip8_sync_fifo.sv`

Synchronous FIFO with push/pop valid-ready semantics, explicit count, read/write pointers, full/empty and overflow. It is suited for event queues inside one clock domain. It includes formal assertions for count bounds, full/empty consistency, pointer/count relation and output stability under backpressure.

Use cases:

- keypad event FIFO/DMA;
- debug log queue;
- staging between producer/consumer units with identical clocks.

#### `chip8_skid_buffer.sv`

Single-entry valid-ready elastic buffer. It decouples producer readiness from consumer readiness and prevents long combinational ready loops. It is used architecturally by the AXI-Lite bridge on AW, W and AR channels.

Use cases:

- AXI-Lite channel input staging;
- register-fabric timing closure;
- any ready/valid path where downstream backpressure must not immediately feed back through a large cone.

### 5.3 Reset infrastructure

#### `chip8_reset_controller.sv`

Reset controller with asynchronous assertion and synchronized release. It forms `rst_req_n` from external reset, PLL lock, DAP reset, watchdog reset and fatal-error reset. A 4-bit shift register releases reset after four clock cycles. Outputs are currently common for SoC, CPU, video, debug and storage.

Use cases:

- board reset conditioning;
- safe SoC reset release;
- debug/watchdog/fatal reset integration.

### 5.4 Reduction infrastructure

#### `chip8_prefix_count.sv`

Parameterized predicate counter. It counts asserted bits in a predicate vector with explicit output width. This centralizes a common reduction pattern and makes the intended datapath shape visible to synthesis and review.

Use cases:

- event source counting;
- key bitmap population count;
- IRQ/debug summaries;
- future video/control predicate networks.

### 5.5 CRC infrastructure

#### `chip8_crc16_ccitt.sv`

Reusable CRC16-CCITT primitive. It is separate from SD host control so CRC polynomial logic does not get duplicated inside protocol FSMs.

Related block:

- `soc/storage/chip8_sd_crc.sv` for SD-specific CRC helpers.

### 5.6 UART infrastructure

#### `chip8_uart_tx.sv`

UART transmitter FSM with IDLE, START, DATA and STOP states. It derives a baud divider from `CLK_HZ / BAUD`, accepts an 8-bit byte through `i_valid`, exposes `o_ready` when idle and drives serial `o_tx` with start/data/stop bit timing.

#### `chip8_uart_rx.sv`

UART receiver primitive for future debug/command input paths. Together with TX, it forms the reusable serial layer underneath the SoC USB/UART debug region.

---

## 6. Layer C — CHIP-8 CPU and native core

### 6.1 Packages

The CHIP-8 package layer defines stable architectural types:

- opcode classes (`chip8_isa_pkg.sv`);
- CPU states, internal ops, micro-ops and illegal-op policy (`chip8_core_pkg.sv`);
- memory layout (`chip8_memmap_pkg.sv`);
- ALU op encoding (`chip8_alu_pkg.sv`);
- display, memory, peripheral and configuration constants.

Internal CHIP-8 memory layout:

```text
0x000 - 0x04F : font area
0x200         : ROM/program base
0xFFF         : last 12-bit RAM address
```

### 6.2 CPU control model

The CPU is an in-order, multi-cycle CHIP-8 core. Its main FSM includes fetch, decode, execute, memory read/write, draw, wait-key, BCD, register burst, ALU flag commit and trap states.

The dominant RTL style is:

```text
state_q / registers_q -> always_comb next-state/control -> state_d/registers_d -> always_ff commit
```

This makes latch avoidance, state transitions and write enables explicit.

### 6.3 Fetch, prefetch and decode

The fetch path reads two bytes and assembles a 16-bit opcode. The prefetch queue can cache sequential fetches when eligible, and must be flushed on branch/jump/call/skip or memory-loader interactions. Decode extracts fields `class`, `x`, `y`, `n`, `kk`, `nnn`, maps them into internal operation enum and marks legality/resource usage.

### 6.4 Datapath, ALU, PC and register file

The datapath computes program-counter targets, memory addresses, draw coordinates and index arithmetic. The ALU computes CHIP-8 byte operations and flag-producing arithmetic/shift operations. The register file stores V0–VF, where VF is collision/carry/borrow/shift flag depending on instruction.

### 6.5 Memory/display/input/timer coupling

The core connects:

- ROM loader and CPU memory writes through a memory arbiter;
- sprite blitter and collision unit into display controller/framebuffer;
- keypad sync/debounce/wait-key into instruction execution;
- delay and sound timers into `Fx07`, `Fx15`, `Fx18` and sound output.

### 6.6 Native SoC

`chip8_native_soc.sv` wraps key synchronization/debounce around `chip8_core` and exposes a clean synthesis boundary for framebuffer, PC, debug, sound and halt outputs. It is the minimal SoC before AXI expansion.

---

## 7. Layer D — AXI/MMIO SoC

### 7.1 AXI-Lite bridge

`chip8_axi_lite_to_reg.sv` converts AXI-Lite into a simple internal register bus. It uses skid buffers on AW, W and AR, captures AW/W independently, joins them into a write request and emits deterministic B/R responses.

### 7.2 Register interconnect

`chip8_reg_interconnect.sv` decodes `addr[15:8]` as the peripheral page and forwards `addr[7:0]` as local offset. Unmapped accesses return a deterministic error marker.

Peripheral pages:

```text
0x10xx VIDEO
0x11xx KEYPAD
0x12xx DMA
0x13xx IRQ
0x14xx DEBUG
0x15xx SD
0x16xx BOOT
0x17xx UART
0x18xx DMA2D
0x19xx DCMIPP
```

The complete programming model is in `REG.md`.

### 7.3 Full AXI SoC

`chip8_axi_soc.sv` connects the full system:

- AXI-Lite register plane;
- SD/SPI host and bootloader;
- ROM load arbiter;
- keypad accelerator;
- native CHIP-8 SoC;
- DMA2D engine;
- DCMIPP/postprocess stage;
- video accelerator/backends;
- DMA status;
- IRQ controller;
- debug register window;
- UART debug/log path.

---

## 8. Layer E — storage and boot path

### 8.1 SD/SPI host

`chip8_sd_spi_host.sv` performs an SD-style SPI read. It has an FSM with IDLE, CMD, WAIT_TOKEN, DATA, CRC0, CRC1, DONE and ERROR states. It supports boot-triggered reads and software-triggered reads, streams bytes with offsets, tracks byte count, timeout, CRC and completion/error state.

### 8.2 Bootloader

`chip8_bootloader.sv` controls boot sequencing:

```text
RESET -> LOG_BOOT -> START_SD -> LOAD -> LOG_RUN -> RELEASE
                                  └────── error -> LOG_ERROR
```

It holds the core in reset while loading ROM bytes and releases the core after a successful boot load. It also emits log bytes such as `BOOT\n`, `RUN\n` and `ERR\n`.

### 8.3 ROM load arbitration

`chip8_rom_load_arbiter.sv` arbitrates among boot ROM load, programmer ROM load and external ROM load sources before sending a single ROM write stream to the native core memory loader.

### 8.4 ROM chunk writer

`chip8_rom_chunk_writer.sv` is a helper for chunked ROM data emission, useful for controlled boot/program streams and validation-driven ROM loading.

---

## 9. Layer F — keypad subprocessor

The keypad subsystem is a small input coprocessor.

Connected path:

```text
4x4 matrix rows/cols
      -> matrix scanner
      -> debounce
      -> stable 16-bit bitmap
      -> event detection
      -> event FIFO/DMA
      -> keypad registers + IRQs
      -> native CHIP-8 key bitmap
```

Main blocks:

- `chip8_keypad_accel.sv`: wrapper/accelerator shell;
- `chip8_keypad_remote_core.sv`: connected remote keypad core;
- `chip8_keypad_matrix_4x4.sv`: row/column scanner;
- `chip8_keypad_regs.sv`: software-visible control/status/FIFO pop registers;
- `chip8_keypad_dma.sv`: event FIFO/DMA support.

This block feeds both the CPU instruction path (`Ex9E`, `ExA1`, `Fx0A`) and the SoC IRQ/MMIO path.

---

## 10. Layer G — video, DMA2D and display subprocessors

### 10.1 Core framebuffer

The CHIP-8 core produces a 64×32 one-bit framebuffer. This framebuffer is both a CPU-visible display result and an input to the SoC-level video pipeline.

### 10.2 DMA2D

`chip8_dma2d_engine.sv` receives the core framebuffer and creates an overlay/processed framebuffer. It supports:

- snapshot;
- clear;
- fill rectangle;
- invert;
- overlay enable/clear;
- done/error IRQ.

It is a full-frame sequencer that walks framebuffer indices and writes an internal overlay RAM.

### 10.3 DCMIPP-style post-processing

`chip8_dcmipp_pipeline.sv` performs post-processing and optional camera/luma capture into the same one-bit framebuffer contract. It supports:

- enable/disable;
- invert;
- grid overlay;
- freeze frame;
- source select;
- luma threshold;
- frame counter;
- frame hash;
- frame IRQ.

### 10.4 Video accelerator and backends

`chip8_video_accel.sv` and `chip8_video_remote_core.sv` select a backend and drive physical video outputs.

Backends:

- `chip8_hdmi_backend.sv`;
- `chip8_lcd_spi_backend.sv`;
- `chip8_lcd_rgb_backend.sv`.

Support blocks:

- `chip8_video_regs.sv` for control/status/IRQ;
- `chip8_video_scaler.sv` for scale mapping;
- `chip8_video_dma_reader.sv` for framebuffer scanout event movement.

Connected path:

```text
core framebuffer -> DMA2D -> DCMIPP -> video remote core -> HDMI / LCD SPI / LCD RGB
```

---

## 11. Layer H — IRQ, debug and observability

### 11.1 IRQ controller

The IRQ controller latches sources into `pending_q`, masks them with `enable_q` and asserts `o_irq` when `pending & enable` is nonzero. Pending bits are cleared by a write-one clear register.

IRQ sources include keypad event/overflow, video frame/vblank/error, key/video DMA done, DMA error, SD done/error, boot done/error, UART RX, DMA2D done/error and DCMIPP frame.

### 11.2 Debug window

The debug page exposes a composite SoC status word and core debug/fault windows. It combines PC, key code, key valid, halted, DCMIPP pixel status, core reset state, SD boot busy and USB log valid.

### 11.3 UART/log path

The SoC allocates a UART MMIO page and instantiates a debug/log UART path in the AXI SoC. The reusable UART TX/RX primitives are available in `lib/common/uart`. If the dedicated `chip8_uart_debug` register implementation is not present in the visible tree, the page should remain documented as reserved/implementation-defined in `REG.md` until that file is added.

---

## 12. Connected flow diagrams

### 12.1 Boot-to-execute flow

```text
Reset asserted
  -> reset controller releases SoC
  -> bootloader holds core
  -> bootloader starts SD read
  -> SD host streams bytes
  -> ROM load arbiter forwards boot stream
  -> native core ROM loader writes CHIP-8 memory at ROM base
  -> bootloader logs RUN and releases core
  -> CPU fetches from 0x200
```

### 12.2 CPU instruction flow

```text
PC -> fetch -> prefetch/decode -> control/resource flags
       -> execute / memory / draw / wait-key / BCD / burst / trap
       -> register file, timers, memory, framebuffer, stack, PC update
```

### 12.3 Keypad flow

```text
matrix scan -> debounce -> key bitmap -> event detect -> FIFO/DMA
       ├── direct CPU key bitmap
       ├── MMIO keypad registers
       └── IRQ controller
```

### 12.4 Video flow

```text
CPU draw -> core framebuffer -> DMA2D -> DCMIPP -> video accelerator
                                      ├── HDMI
                                      ├── LCD SPI
                                      └── LCD RGB
```

### 12.5 AXI/MMIO control flow

```text
AXI-Lite AW/W/AR -> skid buffers -> AXI bridge FSM -> register request
       -> page decode -> peripheral local register
       -> ready/rdata -> AXI response
```

### 12.6 Common library dependency flow

```text
External/board async inputs -> sync_2ff / pulse_sync / async_fifo
AXI/control handshakes      -> skid_buffer / sync_fifo
Board/reset conditions      -> reset_controller
Event vectors/debug masks   -> prefix_count / reduction
Storage integrity           -> CRC16 / SD CRC
Debug serial path           -> UART TX/RX
```

---

## 13. Technique map

| Technique | Blocks | Purpose |
|---|---|---|
| `q/d` state split | CPU, UART, SD, boot, DMA2D, DCMIPP | explicit next-state and deterministic sequential commit |
| `always_comb` defaults | decode, control, interconnect, ALU | avoid hidden latches |
| `ready/valid` | AXI bridge, FIFOs, ROM loader, DMA/event paths | deterministic backpressure |
| skid buffering | AXI AW/W/AR | timing closure and channel decoupling |
| 2FF synchronizer | CDC, key/control inputs | reduce metastability propagation |
| pulse synchronizer | CDC pulse events | preserve one-shot events across clocks |
| Gray-coded async FIFO | CDC payload transfer | safe multi-bit clock crossing |
| reset controller | board/SoC reset | async assertion, synchronized release |
| prefix/reduction | event/debug/vector summaries | reusable explicit reduction datapath |
| CRC | SD/storage | stream integrity support |
| one-hot/predicated datapath | decode/ALU/DMA2D | reduce branchy datapath control |
| MMIO page decode | reg interconnect | simple software-visible SoC control plane |
| IRQ pending/enable/clear | IRQ controller | sticky event aggregation |
| full-frame pipeline | DMA2D/DCMIPP/video | separate CPU drawing from scanout/backend timing |
| formal assertions | FIFO/skid/CDC/CPU/control | invariants for state, stability, bounds and safety |

---

## 14. Documentation set integration

This architecture document should be treated as the root of the technical documentation set.

| Document | Role |
|---|---|
| `ARCHITECTURE.md` | system architecture, full RTL tree, connected paths and technical blocks |
| `BLOCKS.md` | file-by-file block catalog and responsibility table |
| `REG.md` | programmer-visible AXI/MMIO register map and datasheet |
| `ISA.md` | CHIP-8 instruction set implemented by RTL |
| `TECHNICAL_NOTES.md` | RTL methodology, CDC/reset/verification/process notes |
| `VERIFICATION.md` | executable validation matrix and CI/check command map |

Recommended repo layout:

```text
docs/
├── ARCHITECTURE.md
├── BLOCKS.md
├── REG.md
├── ISA.md
├── TECHNICAL_NOTES.md
└── VERIFICATION.md
```

---

## 15. Known integration notes and TODOs

1. The UART page is allocated in the AXI map, and UART TX/RX primitives exist, but the visible tree must include or add the dedicated `chip8_uart_debug` register block for a fully concrete UART MMIO map.
2. Stack overflow/underflow should be connected into debug/fault or IRQ status if not already consumed by the top-level debug path.
3. `lib/common` blocks should be included in lint/formal filelists because they are architectural dependencies of the SoC.
4. Board wrappers should document pin mapping and reset/PLL assumptions per board.
5. `REG.md` and `ISA.md` should be kept generated/reviewed alongside RTL changes to avoid stale software-facing documentation.

---

## 16. Architecture reference material

The design is intentionally small, but its structure follows established SoC and FPGA practice. These references describe the techniques used in the RTL and validation flow:

| Area | Reference | Used here |
|---|---|---|
| Open-source synthesis | [Yosys+nextpnr: an Open Source Framework from Verilog to Bitstream for Commercial FPGAs](https://arxiv.org/abs/1903.10407) | Yosys syntax, synthesis and hierarchy checks |
| Open-source ASIC/SoC flow maturity | [Basilisk open-source SoC flow analysis](https://arxiv.org/abs/2405.04257) | Motivation for scripted, reproducible synthesis and lint flows |
| CDC FIFO design | [Cummings, Simulation and Synthesis Techniques for Asynchronous FIFO Design](https://www.sunburst-design.com/papers/CummingsSNUG2002SJ_FIFO1.pdf) | Gray-coded async FIFO pointers and synchronized opposite-domain pointers |
| SystemVerilog RTL intent | [SystemVerilog language reference](https://en.wikipedia.org/wiki/SystemVerilog) | `always_ff`, `always_comb`, packed structs, typed enums and interfaces |
| Formal hardware checking | [SymbiYosys documentation](https://symbiyosys.readthedocs.io/) | SBY proof/cover jobs for block and SoC invariants |
| RTL simulation/lint | [Verilator documentation](https://verilator.org/guide/latest/) | SystemVerilog lint and compiled simulation regression |
| Licensing metadata | [REUSE Specification](https://reuse.software/spec/) | SPDX file headers and repository-level license compliance |
