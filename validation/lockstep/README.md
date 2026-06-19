<!--
SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
SPDX-License-Identifier: GPL-3.0-only
-->

# CHIP-8 RTL/Rust Lockstep Plan

The lockstep harness compares the Verilated RTL against the Rust `chip8-model`
oracle at opcode retire boundaries.

## Retire Contract

One comparison sample is taken whenever the RTL reports an opcode commit. The
sample must include:

- retired opcode;
- `pc`;
- `i`;
- `v0` through `vf`;
- stack pointer and stack contents;
- delay and sound timers;
- framebuffer hash;
- architectural memory hash for the CHIP-8 program/RAM window.

## Failure Classes

The harness fails immediately on:

- divergent `pc`, `i`, `v*`, stack, timer or framebuffer state;
- timeout before retire;
- illegal opcode that does not match the selected policy;
- RTL deadlock while the Rust oracle can still retire;
- Rust halt while RTL continues retiring instructions.

## Planned Test Entry Points

| Test | Input set | CI level |
|---|---|---|
| `tb_chip8_lockstep_smoke` | `validation/programs/chip8/smoke.ch8` | PR |
| `tb_chip8_lockstep_random_rom` | constrained generated ROMs | nightly |
| `tb_chip8_lockstep_timendus_roms` | Timendus compliance ROMs | nightly |
| `tb_chip8_lockstep_fuzz_seed` | seed-reproducible fuzz ROMs | sign-off |

The trace schema in `trace_schema.json` is the interchange format between the
Verilator harness, Rust oracle and report generator.
