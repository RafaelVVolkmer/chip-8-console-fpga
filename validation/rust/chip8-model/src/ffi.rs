// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
// SPDX-License-Identifier: GPL-3.0-only

use crate::model::Chip8;
use crate::rom::chip8_smoke_rom;
use crate::stress::{Chip8StressResultC, chip8_architecture_stress};

/// C ABI result structure for smoke and stress entry points.
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
#[repr(C)]
pub struct Chip8ResultC {
    /// Program counter after the last executed step.
    pub pc: u16,
    /// Number of draw instructions executed.
    pub draw_count: u32,
    /// Number of lit pixels in the framebuffer.
    pub lit_pixels: u32,
    /// Non-zero if the model halted.
    pub halted: u8,
}

/// Run the smoke ROM through the model and return a C-friendly result.
#[unsafe(no_mangle)]
pub extern "C" fn chip8_run_smoke(max_steps: u32) -> Chip8ResultC {
    let mut chip = Chip8::default();
    chip.load_rom(&chip8_smoke_rom());
    let draw_count = chip.run(max_steps as usize);
    Chip8ResultC {
        pc: chip.pc,
        draw_count,
        lit_pixels: chip.lit_pixels(),
        halted: chip.halted as u8,
    }
}

/// Run the architecture stress harness and return a C-friendly result.
#[unsafe(no_mangle)]
pub extern "C" fn chip8_run_architecture_stress(
    iterations: u32,
) -> Chip8StressResultC {
    chip8_architecture_stress(iterations)
}
