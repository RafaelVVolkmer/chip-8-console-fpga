// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
// SPDX-License-Identifier: GPL-3.0-only

use crate::model::Chip8;
use crate::reference::{alu_ref, lcg_next};

/// C ABI result for the architecture stress harness.
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
#[repr(C)]
pub struct Chip8StressResultC {
    /// Number of exercised cases.
    pub cases: u32,
    /// Rolling checksum over the exercised cases.
    pub checksum: u32,
    /// Number of mismatches observed.
    pub failures: u32,
}

/// Run a deterministic architecture stress pass over the CHIP-8 model.
#[must_use]
pub fn chip8_architecture_stress(iterations: u32) -> Chip8StressResultC {
    let mut rng = 0xc001_c0de;
    let mut checksum = 0u32;
    let mut failures = 0u32;
    let mut cases = 0u32;

    for _ in 0..iterations {
        let a = lcg_next(&mut rng);
        let b = lcg_next(&mut rng);
        for &op in &[0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0xe] {
            let (expected_y, expected_f) = alu_ref(op, a, b);
            let mut chip = Chip8::default();
            chip.v[1] = a;
            chip.v[2] = b;
            let _ = chip.exec(0x8120 | u16::from(op));
            cases += 1;
            checksum = checksum.rotate_left(3)
                ^ u32::from(chip.v[1])
                ^ (u32::from(chip.v[0xf]) << 8);
            failures +=
                u32::from(chip.v[1] != expected_y || chip.v[0xf] != expected_f);
        }

        let mut chip = Chip8::default();
        chip.v[0] = a;
        chip.v[1] = b;
        chip.pc = 0x200;
        let _ = chip.exec(0x3000 | u16::from(a));
        failures += u32::from(chip.pc != 0x202);
        let _ = chip.exec(0x4000 | u16::from(a));
        failures += u32::from(chip.pc != 0x202);
        let _ = chip.exec(0x5010);
        failures += u32::from(chip.pc != if a == b { 0x204 } else { 0x202 });
        let _ = chip.exec(0x9010);
        failures += u32::from(chip.pc != 0x204);
        cases += 4;
        checksum = checksum.rotate_left(5) ^ u32::from(chip.pc);

        chip.pc = 0x260;
        let _ = chip.exec(0x2300);
        failures += u32::from(
            chip.pc != 0x300 || chip.sp != 1 || chip.stack[0] != 0x260,
        );
        let _ = chip.exec(0x00ee);
        failures += u32::from(chip.pc != 0x260 || chip.sp != 0);
        cases += 2;

        chip.keys = 1u16 << (a & 0x0f);
        chip.v[3] = a & 0x0f;
        let pc_before = chip.pc;
        let _ = chip.exec(0xe39e);
        failures += u32::from(chip.pc != pc_before.wrapping_add(2));
        chip.keys = 0;
        let _ = chip.exec(0xe3a1);
        failures += u32::from(chip.pc != pc_before.wrapping_add(4));
        chip.pc = 0x280;
        let _ = chip.exec(0xf30a);
        failures += u32::from(chip.pc != 0x27e);
        chip.keys = 1u16 << (b & 0x0f);
        let _ = chip.exec(0xf30a);
        failures += u32::from(chip.v[3] != (b & 0x0f));
        cases += 4;

        chip.v[4] = a;
        let _ = chip.exec(0xf415);
        let _ = chip.exec(0xf418);
        failures += u32::from(chip.delay != a || chip.sound != a);
        let _ = chip.step();
        failures += u32::from(
            chip.delay != a.saturating_sub(1)
                || chip.sound != a.saturating_sub(1),
        );
        chip.i = 0x300;
        let _ = chip.exec(0xf433);
        failures += u32::from(
            chip.mem[0x300] != a / 100
                || chip.mem[0x301] != (a / 10) % 10
                || chip.mem[0x302] != a % 10,
        );
        cases += 3;

        for idx in 0..16 {
            chip.v[idx] = a.wrapping_add(idx as u8);
        }
        chip.i = 0x340;
        let _ = chip.exec(0xff55);
        chip.v.fill(0);
        let _ = chip.exec(0xff65);
        for idx in 0..16 {
            failures += u32::from(chip.v[idx] != a.wrapping_add(idx as u8));
            checksum = checksum.rotate_left(1) ^ u32::from(chip.v[idx]);
            cases += 1;
        }

        chip.v[0] = a & 63;
        chip.v[1] = b & 31;
        chip.i = 0x380;
        chip.mem[0x380] = 0b1000_0001;
        let _ = chip.exec(0xd011);
        let lit_after_first = chip.lit_pixels();
        failures += u32::from(lit_after_first != 2);
        failures += u32::from(chip.v[0xf] != 0);
        let _ = chip.exec(0xd011);
        failures += u32::from(chip.lit_pixels() != 0 || chip.v[0xf] != 1);
        cases += 4;
        checksum = checksum.rotate_left(7) ^ lit_after_first;
    }

    Chip8StressResultC {
        cases,
        checksum,
        failures,
    }
}
