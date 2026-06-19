// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
// SPDX-License-Identifier: GPL-3.0-only

/// Advance the linear-congruential generator and return the next byte.
#[must_use]
pub fn lcg_next(state: &mut u32) -> u8 {
    *state = state.wrapping_mul(1_664_525).wrapping_add(1_013_904_223);
    (*state >> 24) as u8
}

/// Compute the expected CHIP-8 ALU result for a single nibble opcode family.
#[must_use]
pub fn alu_ref(op: u8, a: u8, b: u8) -> (u8, u8) {
    match op {
        0x0 => (b, 0),
        0x1 => (a | b, 0),
        0x2 => (a & b, 0),
        0x3 => (a ^ b, 0),
        0x4 => {
            let sum = u16::from(a) + u16::from(b);
            (sum as u8, (sum > 0xff) as u8)
        }
        0x5 => {
            let (value, borrow) = a.overflowing_sub(b);
            (value, (!borrow) as u8)
        }
        0x6 => (a >> 1, a & 1),
        0x7 => {
            let (value, borrow) = b.overflowing_sub(a);
            (value, (!borrow) as u8)
        }
        0xe => (a << 1, (a >> 7) & 1),
        _ => (a, 0),
    }
}
