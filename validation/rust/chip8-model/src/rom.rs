// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
// SPDX-License-Identifier: GPL-3.0-only

/// Build the smoke-test ROM used by the validation suite.
#[must_use]
pub fn chip8_smoke_rom() -> Vec<u8> {
    words_to_bytes(&[
        0x00e0, // cls
        0x6008, // v0 = x
        0x6108, // v1 = y
        0xa000, // I = digit 0 sprite
        0xd015, // draw 5-byte sprite
        0x7008, // move x
        0x620a, // v2 = 10
        0x8024, // add v2 to v0
        0xa005, // I = digit 1 sprite
        0xd015, // draw 5-byte sprite
        0x1214, // loop on itself
    ])
}

/// Convert big-endian CHIP-8 opcodes into byte order suitable for memory.
#[must_use]
pub fn words_to_bytes(words: &[u16]) -> Vec<u8> {
    let mut bytes = Vec::with_capacity(words.len() * 2);
    for &word in words {
        bytes.push((word >> 8) as u8);
        bytes.push(word as u8);
    }
    bytes
}

/// Pad a ROM to a 512-byte SD boot image boundary.
#[must_use]
pub fn sd_boot_image(rom: &[u8]) -> Vec<u8> {
    let blocks = rom.len().max(1).div_ceil(512);
    let mut image = vec![0u8; blocks * 512];
    image[..rom.len()].copy_from_slice(rom);
    image
}
