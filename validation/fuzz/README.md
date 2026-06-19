<!--
SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
SPDX-License-Identifier: GPL-3.0-only
-->

# CHIP-8 Fuzzing Plan

The fuzzing strategy uses constrained ROM generation instead of arbitrary byte
streams. Generated programs should:

- mix legal opcodes from all CHIP-8 classes;
- bound call depth and return balance;
- keep jump targets inside initialized ROM regions;
- inject a controlled ratio of illegal opcodes;
- include draw, skip, timer and keypad interactions;
- emit the seed and ROM bytes for deterministic reproduction.

Bug criteria are RTL/Rust divergence, assertion failure, simulation timeout,
unexpected PC loop, framebuffer hash mismatch, stack overflow or stack
underflow.

The current Rust validation engine already runs deterministic randomized
program fuzzing. Future `cargo-fuzz` or AFL++ harnesses should reuse the same
generator and lockstep trace schema.
