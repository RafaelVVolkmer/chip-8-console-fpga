// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
// SPDX-License-Identifier: GPL-3.0-only

use crate::constants::FB_SIZE;

/// Number of logical framebuffer banks used by the helper model.
pub const FRAMEBUFFER_BANKS: usize = 4;
/// Latency, in cycles, before an elastic write becomes observable.
pub const ELASTIC_WRITE_LATENCY: usize = 1;

/// Return whether an opcode is eligible for prefetch in the microarchitecture.
#[must_use]
pub fn prefetch_eligible(opcode: u16) -> bool {
    let low = opcode & 0x00ff;
    match opcode & 0xf000 {
        0x0000 => opcode == 0x00e0,
        0x6000 | 0x7000 | 0xa000 | 0xc000 => true,
        0x8000 => (opcode & 0x000f) <= 0x0003,
        0xf000 => matches!(low, 0x07 | 0x15 | 0x18 | 0x1e | 0x29),
        _ => false,
    }
}

/// Return whether a prefetch should be flushed after the given event.
#[must_use]
pub fn prefetch_flush_required(opcode: u16, memory_write: bool) -> bool {
    memory_write || !prefetch_eligible(opcode)
}

/// Split a pixel index into a bank index and a local index within that bank.
#[must_use]
pub fn framebuffer_bank(pixel_index: usize) -> (usize, usize) {
    let bank_bits = FB_SIZE / FRAMEBUFFER_BANKS;
    (pixel_index / bank_bits, pixel_index % bank_bits)
}

/// Count the number of asserted predicate bits in a slice.
#[must_use]
pub fn prefix_count(predicates: &[bool]) -> usize {
    predicates.iter().filter(|&&predicate| predicate).count()
}

/// Return whether an elastic write is visible after the given read cycle.
#[must_use]
pub fn elastic_write_visible(accept_cycle: usize, read_cycle: usize) -> bool {
    read_cycle >= accept_cycle + ELASTIC_WRITE_LATENCY
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn prefetch_is_limited_to_sequential_non_speculative_opcodes() {
        for opcode in [0x00e0, 0x6123, 0x7101, 0x8123, 0xa200, 0xc1f0] {
            assert!(prefetch_eligible(opcode), "{opcode:04x}");
        }

        for opcode in [0x00ee, 0x1200, 0x2200, 0x3100, 0xd125, 0xf10a] {
            assert!(prefetch_flush_required(opcode, false), "{opcode:04x}");
        }

        assert!(prefetch_flush_required(0x6123, true));
    }

    #[test]
    fn banked_framebuffer_splits_canonical_pixel_space() {
        assert_eq!(framebuffer_bank(0), (0, 0));
        assert_eq!(
            framebuffer_bank((FB_SIZE / FRAMEBUFFER_BANKS) - 1),
            (0, 511)
        );
        assert_eq!(framebuffer_bank(FB_SIZE / FRAMEBUFFER_BANKS), (1, 0));
        assert_eq!(framebuffer_bank(FB_SIZE - 1), (3, 511));
    }

    #[test]
    fn prefix_count_matches_scalar_reference() {
        let predicates = [
            true, false, true, true, false, false, true, false, true, true,
        ];
        assert_eq!(prefix_count(&predicates), 6);
    }

    #[test]
    fn elastic_write_is_observable_after_one_boundary() {
        assert!(!elastic_write_visible(10, 10));
        assert!(elastic_write_visible(10, 11));
        assert!(elastic_write_visible(10, 12));
    }
}
