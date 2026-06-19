<!--
SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
SPDX-License-Identifier: GPL-3.0-only
-->

# Simulation Validation

This directory contains simulation-only validation collateral.

## Layout

- `core/`: CHIP-8 core testbenches and block-level checks.
- `soc/`: AXI, boot, debug, keypad and video subsystem testbenches.
- `boards/`: board integration testbenches with board-level pin surfaces.
- `verilator/`: optional C++ harnesses for custom Verilator debug runs.

The standard flow uses `scripts/simulation/verilator_sim.sh`, which selects a
SystemVerilog testbench by `TOP` and compiles it with the root `files.f`
manifest. Keep generated simulation output outside this tree under `obj/`,
`build`, `generated` or `reports`.

## Common Targets

Run the normal simulation set through Make:

```sh
make chip8-components-sim
make chip8-blocks-sim
make chip8-sim
make axi-sim
make chip8-roms-sim
```

ROM inputs live under `validation/programs`, and Rust/FFI reference-model
checks live under `validation/rust` and `validation/ffi`.
