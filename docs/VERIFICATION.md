<!--
SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
SPDX-License-Identifier: GPL-3.0-only
-->

# CHIP-8 Console FPGA Verification and Validation Plan

This document describes the executable verification strategy for the RTL, Rust reference model, FFI bridge, documentation and CI infrastructure.

The goal is not one monolithic test. The repository uses layered checks so each
tool owns a narrow class of risk, and the top-level `make check` always runs
repository linters before hardware/software tests:

```text
linters -> validation metadata -> Rust model -> FFI -> RTL simulation -> formal -> synthesis -> coverage
```

The GitHub Actions workflows call the same Makefile entry points used locally.
This keeps PR, nightly and sign-off behavior versioned in one place instead of
duplicating command sequences in YAML.

The executable validation plan lives under `validation/testplans/`. Each
`*.testplan.yml` file maps feature, test, coverage intent, status, CI job and
artifact into a parseable matrix.

```sh
make testplan-check
make validation-report
```

Generated outputs:

```text
reports/validation/status.json
reports/validation/summary.md
reports/validation/index.html
```

Validation levels:

| Level | Command policy | Purpose |
|---|---|---|
| PR | `make quick-check` | linters plus fast regression and traceability checks |
| Verilator PR job | `make ci-verilator-pr` | Verilator lint/sim, fuzz ROM generation and validation report |
| Nightly | `make ci-nightly` | linters, ROM corpus, formal, fuzz ROMs, coverage and report |
| Formal nightly | `make ci-formal-nightly` | all formal proof and cover targets plus report |
| Coverage nightly | `make ci-coverage-nightly` | fuzz ROM generation and Verilator coverage |
| Board weekly | `make ci-board-synth-weekly` | all board smoke preflights plus open-source board checks |
| Sign-off | `make ci-signoff` | full local sign-off plus all board smoke preflights |

## 0. Makefile target policy

Every executable check has a singular Make target. Aggregate targets only
sequence those singular targets.

Top-level targets:

| Target | Expands to |
|---|---|
| `make lint-all` | license, Markdown, YAML, Actions, TOML, JSON, shell, spelling, links, Verilator lint and `svlint` |
| `make validation-infra-check` | testplan parser, cocotb syntax, CSR metadata and lockstep schema checks |
| `make pr-regression` | validation metadata, Rust/FFI, smoke sims, AXI/SoC sims, Yosys checks, report and formal syntax |
| `make regression` | `pr-regression`, ROM corpus simulation and all formal proof targets |
| `make full-regression` | `regression` plus formal cover |
| `make check` | `lint-all`, `full-regression`, synthesis and Verilator coverage |
| `make clean` | removes generated simulation, formal, synthesis, coverage, Rust, report, ROM and vendor artifacts |

Singular RTL simulation targets:

| Target | Testbench |
|---|---|
| `make chip8-components-sim` | `tb_chip8_components` |
| `make chip8-blocks-sim` | `tb_chip8_blocks_exhaustive` |
| `make chip8-sim` | `tb_chip8_top` with generated smoke ROM memory |
| `make tb-chip8-axi-lite-sim` | `tb_chip8_axi_lite` |
| `make tb-chip8-keypad-remote-core-sim` | `tb_chip8_keypad_remote_core` |
| `make tb-chip8-video-remote-core-sim` | `tb_chip8_video_remote_core` |
| `make tb-tang-nano-9k-top-sim` | `tb_tang_nano_9k_top` |
| `make tb-chip8-boot-pipeline-sim` | `tb_chip8_boot_pipeline` |
| `make tb-chip8-dap-protocol-sim` | `tb_chip8_dap_protocol` |

Singular formal targets:

| Target | SymbiYosys file |
|---|---|
| `make formal-chip8-protocol-blocks` | `validation/formal/protocol/chip8_protocol_blocks.sby` |
| `make formal-chip8-blocks` | `validation/formal/core/chip8_blocks.sby` |
| `make formal-chip8-components` | `validation/formal/core/chip8_components.sby` |
| `make formal-chip8-top` | `validation/formal/core/chip8_top.sby` |
| `make formal-chip8-boot-pipeline` | `validation/formal/soc/axi/chip8_boot_pipeline.sby` |
| `make formal-chip8-soc-axi` | `validation/formal/soc/axi/chip8_soc_axi.sby` |
| `make formal-chip8-keypad` | `validation/formal/soc/keypad/chip8_keypad.sby` |
| `make formal-chip8-video` | `validation/formal/soc/video/chip8_video.sby` |
| `make formal-tang-nano-9k` | `validation/formal/boards/tang_nano_9k/tang_nano_9k.sby` |
| `make formal-cover-chip8` | `validation/formal/coverage/chip8_cover.sby` |

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
| Testplan matrix | `make validation-report` | feature-to-test-to-coverage traceability |
| Cocotb scaffold syntax | `make cocotb-check` | Python testbench entry-point syntax |
| Lockstep contract | `make lockstep-plan` | RTL/Rust comparison trace schema |
| CSR source check | `make csr-check` | parseable register-plan artifacts |

Planned lockstep tests compare the Verilated RTL against the Rust model at
opcode retire boundaries. The comparison contract is documented in
`validation/lockstep/README.md` and uses `trace_schema.json` for report
interchange. Planned cocotb tests live under `validation/cocotb/` for AXI-Lite,
boot, keypad, video and DAP scoreboards.

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
| SPDX/REUSE | `make lint-reuse` |
| Markdown | `make lint-markdown` |
| YAML | `make lint-yaml` |
| GitHub Actions | `make lint-actions` |
| TOML | `make lint-toml` |
| JSON | `make lint-json` |
| Shell diagnostics | `make lint-shellcheck` |
| Shell formatting | `make lint-shfmt` |
| Links | `make lint-links` |
| Spelling | `make lint-typos` |
| Verilator lint | `make lint-verilator` |
| `svlint` | `make lint-svlint` |
| All linters | `make lint-all` |
| Validation report | `make validation-infra-check validation-report` |

Each gate has a dedicated GitHub Actions workflow so failures are localized.

## 7. Full local sign-off

The broad local sign-off target is:

```sh
make check
```

This runs all repository linters first, then validation metadata checks, Rust
validation, FFI, Verilator simulation, ROM regression, formal checks, synthesis
checks and coverage.

For CI parity, use the level-specific aliases:

```sh
make ci-pr
make ci-nightly
make ci-signoff
```

Clean generated state with:

```sh
make clean
```

`make clean` removes generated Verilator objects, Yosys/synthesis reports,
coverage outputs, fuzz ROMs, formal working directories, Rust build outputs,
board smoke reports, generated `.mem` ROM images, vendor project artifacts and
common simulator trace files. It intentionally preserves source files,
licenses and checked-in documentation.

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
