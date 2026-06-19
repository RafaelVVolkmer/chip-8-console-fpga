//! Validation engine and behavioral models for the CHIP-8 FPGA project.
//!
//! The crate is split into small modules so the executable, FFI surface and
//! validation suite can evolve independently without duplicating CHIP-8
//! semantics.

// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
// SPDX-License-Identifier: GPL-3.0-only

#![deny(missing_docs)]

/// Shared constants for the CHIP-8 validation model.
pub mod constants;
/// FFI bindings used by downstream host integrations.
pub mod ffi;
/// Microarchitectural contract helpers.
pub mod microarchitecture;
/// Cycle-accurate CHIP-8 behavioral model.
pub mod model;
/// Reference helpers for opcode and pseudo-random checks.
pub mod reference;
/// ROM packaging helpers.
pub mod rom;
/// Architecture stress and fuzz helpers.
pub mod stress;
/// Validation suite orchestration.
pub mod validation;
/// Framebuffer and video pipeline helpers.
pub mod video_pipeline;

/// CHIP-8 framebuffer width in pixels.
pub use constants::{FB_SIZE, FONT, HEIGHT, ROM_BASE, WIDTH};
/// C ABI helpers for smoke and stress execution.
pub use ffi::{Chip8ResultC, chip8_run_architecture_stress, chip8_run_smoke};
/// CHIP-8 behavioral model.
pub use model::Chip8;
/// ROM and image helpers used by validation harnesses.
pub use rom::{chip8_smoke_rom, sd_boot_image, words_to_bytes};
/// Deterministic architecture stress helper and result structure.
pub use stress::{Chip8StressResultC, chip8_architecture_stress};
