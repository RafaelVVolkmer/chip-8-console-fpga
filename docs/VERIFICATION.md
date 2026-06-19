<!--
SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
SPDX-License-Identifier: GPL-3.0-only
-->

# CHIP-8 Console FPGA Verification and Validation Plan

This document describes the executable verification strategy for the RTL, Rust reference model, FFI bridge, documentation and CI infrastructure.

The goal is not one monolithic test. The repository uses layered checks so each tool owns a narrow class of risk:

```text
style/config -> Rust model -> FFI -> RTL lint -> RTL simulation -> formal -> synthesis -> coverage -> docs/license links
```

## 1. Verification scope

| Scope | Primary artifacts | Main risk covered |
|---|---|---|
| CHIP-8 ISA behavior | `validation/rust/chip8-model`, `validation/simulation/core` | opcode semantics, PC behavior, flags, memory and display side effects |
| CPU microarchitecture | `rtl/core/chip8/cpu`, formal core targets | FSM validity, prefetch flush, skip behavior, ALU flag commit, burst sequencing |
| Core memory/video/input | `rtl/core/chip8/memory`, `video`, `input`, `timers` | address bounds, framebuffer writes, debounce/wait-key, timer behavior |
| SoC register plane | `rtl/soc/bus`, `docs/REG.md`, AXI testbenches | AXI-Lite handshakes, page decode, status/clear behavior |
| Boot/storage | `rtl/soc/storage`, boot pipeline tests | SD/SPI stream handling, ROM chunk writes, core hold/release |
| Video/keypad subprocessors | `rtl/soc/peripherals`, Rust validation contracts | DMA2D, DCMIPP, remote keypad, FIFO and IRQ contracts |
| Board integration | board wrappers, Tang Nano formal/sim/synthesis checks | reset/clock adaptation, top-level connectivity, board-facing smoke checks |
| Repository quality | workflows, scripts, docs, license metadata | reproducibility, SPDX compliance, Markdown/YAML/TOML/shell correctness |

## 2. Validation model

The Rust engine in `validation/rust/chip8-model` is the executable behavioral oracle for CHIP-8 and SoC-adjacent contracts.

It validates:

- smoke ROM execution and boot-image packing;
- ALU operations against scalar reference equations;
- control-flow and memory edge cases;
- draw wrapping and collision behavior;
- randomized program invariants over `PC`, `I`, stack depth and framebuffer bounds;
- bundled ROM execution without state corruption;
- DMA2D, DCMIPP and microarchitecture helper contracts;
- FFI export compatibility through `validation/ffi/tests/c_calls_rust.c`.

Strict Rust gates:

```sh
cd validation/rust
cargo fmt --all --check
RUSTFLAGS="-D warnings" cargo check-all
RUSTFLAGS="-D warnings" cargo clippy-all
RUSTFLAGS="-D warnings" cargo test-release
RUSTDOCFLAGS="-D warnings" cargo doc-strict
RUSTFLAGS="-D warnings" cargo build-release
```

The local aggressive nightly target is intentionally separate because it uses host-specific and unstable flags:

```sh
make rust-nightly-aggressive
```

That target builds the final `staticlib` FFI artifact. It does not replace the stable CI path.

## 3. RTL lint and simulation

RTL syntax/style is checked at three levels:

| Tool | Command | Purpose |
|---|---|---|
| `svlint` | `svlint -c .svlint.toml ...` | SystemVerilog style and structural lint |
| Verilator core lint | `bash scripts/verification/verilator_lint.sh` | core and core-testbench elaboration |
| Verilator SoC lint | `bash scripts/verification/verilator_axi_lint.sh` | AXI, SoC, board and peripheral elaboration |

Simulation targets:

| Target | Command | Coverage intent |
|---|---|---|
| component stress | `make chip8-components-sim` | library/core block interactions |
| exhaustive block regression | `make chip8-blocks-sim` | CPU helper and edge-case blocks |
| CHIP-8 smoke ROM | `make chip8-sim` | CPU, memory and display integration |
| AXI/SoC simulation | `make axi-sim` | register, keypad, video, boot and DAP flows |
| ROM corpus | `make chip8-roms-sim` | bundled CHIP-8 program regression |
| Verilator coverage | `make coverage` | instrumented core/SoC simulation coverage reports |

## 4. Formal verification

SymbiYosys targets are organized by contract boundary:

| Target | Scope | Main properties |
|---|---|---|
| `validation/formal/protocol/chip8_protocol_blocks.sby` | common protocol blocks | handshake stability, FIFO and CDC protocol assumptions |
| `validation/formal/core/chip8_blocks.sby` | CPU helper blocks | decode/control/datapath/local invariants |
| `validation/formal/core/chip8_components.sby` | reusable core components | register, stack, timer, framebuffer and memory bounds |
| `validation/formal/core/chip8_top.sby` | integrated core | top-level core invariants |
| `validation/formal/soc/axi/chip8_boot_pipeline.sby` | boot pipeline | ROM stream/core release safety |
| `validation/formal/soc/axi/chip8_soc_axi.sby` | AXI SoC | register plane and integration invariants |
| `validation/formal/soc/keypad/chip8_keypad.sby` | keypad path | debounce/FIFO/event behavior |
| `validation/formal/soc/video/chip8_video.sby` | video path | DMA2D/DCMIPP/video register behavior |
| `validation/formal/boards/tang_nano_9k/tang_nano_9k.sby` | board top | top-level reset and connectivity assumptions |
| `validation/formal/coverage/chip8_cover.sby` | cover reachability | proof that key architectural events are reachable |

Run:

```sh
make formal
make formal-cover
```

## 5. Synthesis checks

Yosys jobs ensure the RTL stays elaborable and structurally synthesizable:

| Command | Scope |
|---|---|
| `yosys -q scripts/verification/yosys_check.ys` | CHIP-8 core synthesis check |
| `yosys -q scripts/verification/yosys_soc_axi_check.ys` | AXI SoC synthesis check |
| `yosys -q scripts/verification/yosys_tang_nano_9k_check.ys` | Tang Nano 9K board-top synthesis check |
| `make synthesis` | generic synthesis plus SoC and board structural checks |

Warnings such as framebuffer memory expansion are reviewed as synthesis-shape information, not ignored blindly.

## 6. Repository quality gates

| Gate | Command |
|---|---|
| SPDX/REUSE | `reuse lint` |
| Markdown | `npx --yes markdownlint-cli2 "**/*.md" "#generated/**" "#reports/**" "#validation/rust/target/**"` |
| YAML | `yamllint .github/workflows .yamllint.yml` |
| GitHub Actions | `actionlint -color` |
| TOML | `taplo lint ...` and `taplo format --check ...` |
| Shell diagnostics | `shellcheck scripts/**/*.sh` |
| Shell formatting | `shfmt -d -i 4 -ci scripts/**/*.sh` |
| Links | `lychee --config .lychee.toml README.md "docs/**/*.md" validation/simulation/README.md` |
| Spelling | `typos` |

Each gate has a dedicated GitHub Actions workflow so failures are localized.

## 7. Full local sign-off

The broad local sign-off target is:

```sh
make check
```

This runs license compliance, Rust validation, FFI, Verilator lint/simulation, ROM regression, formal checks, synthesis checks, coverage and configuration checks.

Before opening a release-quality pull request, also run the singular infrastructure checks:

```sh
reuse lint
npx --yes markdownlint-cli2 "**/*.md" "#generated/**" "#reports/**" "#validation/rust/target/**"
yamllint .github/workflows .yamllint.yml
actionlint -color
taplo lint .lychee.toml .svlint.toml .typos.toml REUSE.toml validation/rust/Cargo.toml validation/rust/chip8-model/Cargo.toml validation/rust/.cargo/config.toml validation/rust/.cargo/nightly-aggressive.toml validation/rust/rustfmt.toml
taplo format --check .lychee.toml .svlint.toml .typos.toml REUSE.toml validation/rust/Cargo.toml validation/rust/chip8-model/Cargo.toml validation/rust/.cargo/config.toml validation/rust/.cargo/nightly-aggressive.toml validation/rust/rustfmt.toml
shellcheck scripts/**/*.sh
shfmt -d -i 4 -ci scripts/**/*.sh
typos
lychee --config .lychee.toml README.md "docs/**/*.md" validation/simulation/README.md
```

## 8. Reference material

| Topic | Reference |
|---|---|
| Asynchronous FIFO and Gray pointers | [Cummings async FIFO design paper](https://www.sunburst-design.com/papers/CummingsSNUG2002SJ_FIFO1.pdf) |
| Open-source FPGA synthesis | [Yosys+nextpnr framework paper](https://arxiv.org/abs/1903.10407) |
| Formal flow | [SymbiYosys documentation](https://symbiyosys.readthedocs.io/) |
| RTL lint/simulation | [Verilator guide](https://verilator.org/guide/latest/) |
| Rust toolchain | [Rust documentation](https://doc.rust-lang.org/) |
| Rust lints | [Clippy documentation](https://doc.rust-lang.org/clippy/) |
| Rust formatting | [rustfmt documentation](https://rust-lang.github.io/rustfmt/) |
| SPDX compliance | [REUSE Specification](https://reuse.software/spec/) |
