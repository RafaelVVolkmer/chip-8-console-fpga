<!--
SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
SPDX-License-Identifier: GPL-3.0-only
-->

# CHIP-8 Console FPGA — Technical Notes and RTL Process

This document connects the architecture to the concrete RTL techniques used across the repository.

---

## 1. RTL style contract

The project follows a hardware-reviewable SystemVerilog style:

- SPDX and copyright header in RTL files.
- ``default_nettype none`` at file scope, restored at EOF.
- Semantic localparams instead of unexplained magic numbers.
- `always_ff` for sequential state.
- `always_comb` for combinational logic.
- `q/d` naming for registered and next-state signals where applicable.
- Ready/valid contracts for data movement.
- Deterministic reset values for stateful blocks.
- Formal assertions around stability, bounds and state validity.

---

## 2. Ready/valid and elastic buffering

The SoC uses ready/valid style handshakes for AXI-facing register conversion, ROM load streams, FIFOs and event movement.

Rules:

1. Payload is valid only when `valid=1`.
2. Transfer happens when `valid && ready`.
3. Payload must remain stable while `valid && !ready`.
4. Backpressure must not form large timing-critical combinational loops.

The `chip8_skid_buffer` is the primary one-entry elasticity primitive. It is used to stage AXI AW, W and AR channels before the internal register FSM.

---

## 3. CDC process

CDC must be selected by payload type:

| Crossing type | Correct primitive |
|---|---|
| single stable bit | `chip8_sync_2ff` |
| one-shot pulse | `chip8_pulse_sync` |
| multi-bit payload stream | `chip8_async_fifo` |
| same-clock buffering | `chip8_sync_fifo` |

Do not synchronize a multi-bit changing bus with independent 2FF chains unless the bus is Gray-coded, stable under handshake, or otherwise encoded safely.

---

## 4. Reset process

Reset policy:

- assert reset immediately when external reset, PLL unlock, DAP reset, watchdog reset or fatal error occurs;
- release reset synchronously after a shift-register delay;
- keep SoC, CPU, video, debug and storage reset releases aligned unless a subsystem later requires independent sequencing.

The reset controller currently exposes common synchronized reset outputs for SoC, CPU, video, debug and storage.

---

## 5. FIFO process

Synchronous FIFO is used for single-clock buffering; async FIFO is used for true CDC.

Expected properties:

- no pop when empty;
- no push when full unless overflow is intentionally latched;
- output remains stable under pop-side backpressure;
- count/pointer relationship remains consistent;
- async FIFO pointers cross domains in Gray code.

---

## 6. AXI-Lite process

AXI-Lite is converted into a simple register request interface:

```text
AW/W skid buffers -> join write request -> wait peripheral ready -> B response
AR skid buffer    -> read request       -> wait peripheral ready -> R response
```

The MMIO interconnect then decodes `addr[15:8]` into peripheral page and forwards `addr[7:0]` as the local offset.

---

## 7. CPU execution process

The CHIP-8 CPU is intentionally in-order and multi-cycle. Expensive or stateful instructions are split into explicit states:

- `DRAW` for sprite draw;
- `WAIT_KEY` for `Fx0A`;
- `BCD0/BCD1/BCD2` for `Fx33`;
- `STORE`/`LOAD` for `Fx55`/`Fx65`;
- `ALU_FLAG` for explicit VF commit;
- `TRAP` for illegal-op handling.

This makes waveform review easier and avoids hiding multi-byte work inside opaque combinational blocks.

---

## 8. Video process

The video path is deliberately separated from CPU draw timing:

```text
CPU framebuffer -> DMA2D overlay -> DCMIPP postprocess -> video backend
```

That allows:

- CPU draw to remain CHIP-8 simple;
- DMA2D full-frame operations to be independent;
- DCMIPP-like postprocess/capture to be inserted before scanout;
- HDMI/LCD backends to consume normalized one-bit framebuffer data.

---

## 9. Keypad process

The keypad is treated as a subprocessor:

```text
matrix scanner -> debounce -> stable bitmap -> event detect -> FIFO/DMA -> IRQ/MMIO/core
```

This separates physical key scanning from CHIP-8 instruction semantics.

---

## 10. Boot/storage process

Boot path:

```text
bootloader -> SD/SPI host -> byte stream -> ROM load arbiter -> core ROM loader -> core memory
```

The bootloader holds the core until load completes, logs boot/run/error markers and releases the CPU only after a successful boot sequence.

---

## 11. Verification hooks

Formal/lint targets should include:

- state validity for every FSM;
- ready/valid stability under backpressure;
- FIFO count bounds and empty/full consistency;
- async FIFO Gray-code one-bit pointer transitions;
- reset release assumptions;
- address decode default behavior;
- no X-propagating unmapped reads;
- display coordinate bounds;
- illegal-op policy behavior.

See [`VERIFICATION.md`](./VERIFICATION.md) for the executable validation matrix, tool commands and CI split.

---

## 12. Tooling and quality gate process

The repository treats verification as a layered quality gate:

| Layer | Tooling | Purpose |
|---|---|---|
| SPDX/license | `reuse lint` | Confirms each source has machine-readable license metadata. |
| Markdown | `markdownlint-cli2` plus local `check_conf.sh` | Keeps architecture docs readable and structurally consistent. |
| YAML/Actions | `yamllint`, `actionlint` | Catches workflow syntax, shell interpolation and GitHub Actions mistakes. |
| TOML | `taplo lint`, `taplo format --check` | Checks Cargo and project configuration. |
| Shell | `shellcheck`, `shfmt -d -i 4 -ci` | Checks scripts for portability, quoting and consistent formatting. |
| Rust | `cargo fmt`, `cargo check`, `cargo clippy`, `cargo test`, `cargo doc`, `cargo build` | Verifies the behavioral model, FFI surface and documentation. |
| RTL | `svlint`, Verilator, Yosys, SymbiYosys | Checks style, simulation behavior, synthesis structure and formal invariants. |

CI keeps these gates split into small workflows so a failure points directly to the broken layer.

---

## 13. Reference material

| Technique | Reference | Local rule |
|---|---|---|
| `always_ff`/`always_comb`, typed enums and packed structs | [SystemVerilog language reference](https://en.wikipedia.org/wiki/SystemVerilog) | Use intent-specific procedural blocks and typed structures instead of untyped ad hoc logic. |
| CDC by payload class | [Cummings async FIFO paper](https://www.sunburst-design.com/papers/CummingsSNUG2002SJ_FIFO1.pdf) | Use 2FF for single bits, toggle sync for pulses and Gray-pointer FIFO for payloads. |
| Ready/valid stability | AMBA AXI and ACE protocol specification | Hold payload stable while `valid && !ready`; isolate long ready paths with skid buffers. |
| Open-source FPGA synthesis | [Yosys+nextpnr framework paper](https://arxiv.org/abs/1903.10407) | Keep file lists and synthesis checks scriptable and reproducible. |
| Formal proof/cover flow | [SymbiYosys documentation](https://symbiyosys.readthedocs.io/) | Keep bounded proofs close to the block contract and use cover for reachability. |
| Compiled RTL simulation | [Verilator guide](https://verilator.org/guide/latest/) | Use Verilator for fast lint/regression and coverage instrumentation. |
| Rust safety model | [Rust documentation](https://doc.rust-lang.org/) | Keep the validation engine dependency-light, documented and warning-clean. |
| Rust linting | [Clippy documentation](https://doc.rust-lang.org/clippy/) | Treat Clippy warnings as errors in CI. |
| Rust formatting | [rustfmt documentation](https://rust-lang.github.io/rustfmt/) | Enforce deterministic Rust formatting before check/test. |
| License metadata | [REUSE Specification](https://reuse.software/spec/) | Require SPDX metadata on every committed file. |

---

## 14. Documentation maintenance rule

Any RTL change that modifies one of these must update docs in the same commit:

| RTL change | Required doc update |
|---|---|
| MMIO address/register bit changes | `REG.md` |
| opcode/decode/control change | `ISA.md` |
| module/file/tree integration change | `ARCHITECTURE.md` and `BLOCKS.md` |
| CDC/FIFO/reset method change | `TECHNICAL_NOTES.md` |
| board pin/clock/reset change | board section in `ARCHITECTURE.md` |

Recommended commit pattern:

```text
docs(architecture): update SoC technical documentation

Motivation: keep architecture, register and ISA references aligned with RTL.
Details: update connected block map, MMIO pages, common library primitives and process notes.
Impact: improves bring-up, review, verification planning and future driver development.
Signed-off-by: Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
```
