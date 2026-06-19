// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
// SPDX-License-Identifier: GPL-3.0-only

use std::path::{Path, PathBuf};

use crate::constants::{FB_SIZE, ROM_BASE, WIDTH};
use crate::microarchitecture::{
    FRAMEBUFFER_BANKS, elastic_write_visible, framebuffer_bank,
    prefetch_eligible, prefetch_flush_required, prefix_count,
};
use crate::model::Chip8;
use crate::reference::{alu_ref, lcg_next};
use crate::rom::{chip8_smoke_rom, sd_boot_image, words_to_bytes};
use crate::stress::chip8_architecture_stress;
use crate::video_pipeline::{
    Dma2dConfig, Dma2dOp, dcmipp_capture_ycbcr422, dcmipp_postprocess,
    dma2d_apply,
};

/// Aggregated result for one validation pass.
#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct ValidationReport {
    /// Number of assertions or checks that were evaluated.
    pub cases: u64,
    /// Number of failed checks.
    pub failures: u64,
    /// Rolling checksum over the executed checks.
    pub checksum: u64,
}

impl ValidationReport {
    /// Record a single validation check outcome.
    pub fn record(&mut self, passed: bool, salt: u64) {
        self.cases += 1;
        self.failures += u64::from(!passed);
        self.checksum =
            self.checksum.rotate_left(7).wrapping_add(salt ^ self.cases);
    }

    /// Merge another report into this one.
    pub fn merge(&mut self, other: ValidationReport) {
        self.cases += other.cases;
        self.failures += other.failures;
        self.checksum ^= other.checksum.rotate_left(11);
    }

    /// Panic in tests if the report is not clean.
    pub fn assert_clean(&self) {
        assert_eq!(self.failures, 0, "{self:?}");
        assert_ne!(self.checksum, 0, "{self:?}");
    }
}

/// Validation engine configuration.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ValidationConfig {
    /// Number of iterations used by randomized stress tests.
    pub fuzz_iterations: u32,
}

impl ValidationConfig {
    /// Create a new validation configuration.
    #[must_use]
    pub fn new(fuzz_iterations: u32) -> Self {
        Self { fuzz_iterations }
    }
}

/// Orchestrates all validation passes in a deterministic order.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ValidationEngine {
    config: ValidationConfig,
}

impl ValidationEngine {
    /// Create a new validation engine from a configuration.
    #[must_use]
    pub fn new(config: ValidationConfig) -> Self {
        Self { config }
    }

    /// Execute the full validation suite and return the aggregated report.
    #[must_use]
    pub fn run(&self) -> ValidationReport {
        let mut report = ValidationReport::default();
        report.merge(validate_smoke_and_boot());
        report.merge(validate_alu_exhaustive());
        report.merge(validate_opcode_surface());
        report.merge(validate_control_memory_video_edges());
        report.merge(validate_architecture_stress(self.config.fuzz_iterations));
        report.merge(validate_randomized_program_fuzz(
            self.config.fuzz_iterations,
        ));
        report.merge(validate_video_pipeline());
        report.merge(validate_microarchitecture_contracts());
        report.merge(validate_bundled_roms());
        report
    }
}

/// Convenience wrapper used by the CLI and FFI callers.
#[must_use]
pub fn run_validation_suite(fuzz_iterations: u32) -> ValidationReport {
    ValidationEngine::new(ValidationConfig::new(fuzz_iterations)).run()
}

/// Record a validation failure for a missing ROM directory.
fn record_rom_directory_error(report: &mut ValidationReport, path: &Path) {
    report.record(false, path.to_string_lossy().len() as u64);
}

/// Record a boolean validation check and emit a diagnostic on failure.
#[macro_export]
macro_rules! chip8_check {
    ($report:expr, $condition:expr) => {{
        let passed = $condition;
        $report.record(passed, line!() as u64);
        if !passed {
            eprintln!("validation failed: {}", stringify!($condition));
        }
    }};
}

/// Record an equality validation check and emit a diagnostic on failure.
#[macro_export]
macro_rules! chip8_check_eq {
    ($report:expr, $left:expr, $right:expr) => {{
        let left = $left;
        let right = $right;
        let passed = left == right;
        $report.record(
            passed,
            line!() as u64 ^ ((left as u64) << 16) ^ right as u64,
        );
        if !passed {
            eprintln!(
                "validation failed: {} == {}, left={left:?}, right={right:?}",
                stringify!($left),
                stringify!($right)
            );
        }
    }};
}

/// Validate smoke ROM execution and ROM-to-SD image packaging.
fn validate_smoke_and_boot() -> ValidationReport {
    let mut report = ValidationReport::default();
    let mut chip = Chip8::default();
    chip.load_rom(&chip8_smoke_rom());
    let draws = chip.run(16);
    chip8_check_eq!(report, draws, 2);
    chip8_check_eq!(report, chip.lit_pixels(), 22);
    chip8_check_eq!(report, chip.pc, 0x214);

    let rom = chip8_smoke_rom();
    let image = sd_boot_image(&rom);
    chip8_check_eq!(report, image.len(), 512);
    chip8_check!(report, image[rom.len()..].iter().all(|&byte| byte == 0));

    let mut boot_chip = Chip8::default();
    boot_chip.load_rom(&image[..rom.len()]);
    let _ = boot_chip.run(16);
    chip8_check_eq!(report, boot_chip.lit_pixels(), 22);
    report
}

/// Exhaustively validate the ALU helper against the reference model.
fn validate_alu_exhaustive() -> ValidationReport {
    let mut report = ValidationReport::default();
    for a in u8::MIN..=u8::MAX {
        for b in u8::MIN..=u8::MAX {
            for op in [0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0xe] {
                let (expected_vx, expected_vf) = alu_ref(op, a, b);
                let mut chip = Chip8::default();
                chip.v[1] = a;
                chip.v[2] = b;
                let _ = chip.exec(0x8120 | u16::from(op));
                chip8_check_eq!(report, chip.v[1], expected_vx);
                chip8_check_eq!(report, chip.v[0xf], expected_vf);
            }
        }
    }
    report
}

/// Validate opcode-classification helpers across the full 16-bit opcode space.
fn validate_opcode_surface() -> ValidationReport {
    let mut report = ValidationReport::default();
    for opcode in 0u16..=u16::MAX {
        let low = opcode & 0x00ff;
        let expected_prefetch = match opcode & 0xf000 {
            0x0000 => opcode == 0x00e0,
            0x6000 | 0x7000 | 0xa000 | 0xc000 => true,
            0x8000 => (opcode & 0x000f) <= 0x0003,
            0xf000 => matches!(low, 0x07 | 0x15 | 0x18 | 0x1e | 0x29),
            _ => false,
        };
        chip8_check_eq!(report, prefetch_eligible(opcode), expected_prefetch);
        chip8_check_eq!(
            report,
            prefetch_flush_required(opcode, false),
            !expected_prefetch
        );
    }
    report
}

/// Validate control, memory and video edge cases against the model.
fn validate_control_memory_video_edges() -> ValidationReport {
    let mut report = ValidationReport::default();
    let mut chip = Chip8::default();

    chip.v[1] = 0xaa;
    let _ = chip.exec(0x31aa);
    chip8_check_eq!(report, chip.pc, 0x202);
    let _ = chip.exec(0x41aa);
    chip8_check_eq!(report, chip.pc, 0x202);
    let _ = chip.exec(0x51f0);
    chip8_check_eq!(report, chip.pc, 0x202);
    let _ = chip.exec(0x91f0);
    chip8_check_eq!(report, chip.pc, 0x204);

    chip.pc = 0x222;
    let _ = chip.exec(0x2300);
    chip8_check_eq!(report, chip.pc, 0x300);
    chip8_check_eq!(report, chip.sp, 1);
    let _ = chip.exec(0x00ee);
    chip8_check_eq!(report, chip.pc, 0x222);
    chip8_check_eq!(report, chip.sp, 0);

    chip.v[4] = 0x0a;
    chip.keys = 1 << 0x0a;
    let _ = chip.exec(0xe49e);
    chip8_check_eq!(report, chip.pc, 0x224);
    chip.keys = 0;
    let _ = chip.exec(0xe4a1);
    chip8_check_eq!(report, chip.pc, 0x226);

    chip.pc = 0x240;
    let _ = chip.exec(0xf40a);
    chip8_check_eq!(report, chip.pc, 0x23e);
    chip.keys = 1 << 3;
    let _ = chip.exec(0xf40a);
    chip8_check_eq!(report, chip.v[4], 3);

    chip.v[5] = 12;
    let _ = chip.exec(0xf515);
    let _ = chip.exec(0xf518);
    chip8_check_eq!(report, chip.delay, 12);
    chip8_check_eq!(report, chip.sound, 12);
    let _ = chip.exec(0xf507);
    chip8_check_eq!(report, chip.v[5], 12);

    chip.v[0] = 255;
    chip.i = 0x300;
    let _ = chip.exec(0xf033);
    chip8_check_eq!(report, chip.mem[0x300], 2);
    chip8_check_eq!(report, chip.mem[0x301], 5);
    chip8_check_eq!(report, chip.mem[0x302], 5);

    for idx in 0..=0xf {
        chip.v[idx] = idx as u8 ^ 0x5a;
    }
    chip.i = 0x320;
    let _ = chip.exec(0xff55);
    chip.v.fill(0);
    let _ = chip.exec(0xff65);
    for idx in 0..=0xf {
        chip8_check_eq!(report, chip.v[idx], idx as u8 ^ 0x5a);
    }

    chip.v[1] = 0x0f;
    let _ = chip.exec(0xf129);
    chip8_check_eq!(report, chip.i, 75);

    chip.v[2] = 63;
    chip.v[3] = 31;
    chip.i = 0x350;
    chip.mem[0x350] = 0b1000_0001;
    chip8_check!(report, chip.exec(0xd231));
    chip8_check_eq!(report, chip.fb[31 * WIDTH + 63], 1);
    chip8_check_eq!(report, chip.fb[31 * WIDTH + 6], 1);
    chip8_check_eq!(report, chip.v[0xf], 0);
    chip8_check!(report, chip.exec(0xd231));
    chip8_check_eq!(report, chip.fb[31 * WIDTH + 63], 0);
    chip8_check_eq!(report, chip.fb[31 * WIDTH + 6], 0);
    chip8_check_eq!(report, chip.v[0xf], 1);

    chip.v[6] = 0;
    let _ = chip.exec(0xc6f0);
    chip8_check_eq!(report, chip.v[6] & 0x0f, 0);
    report
}

/// Stress the architecture model with randomized ALU, stack and draw cases.
fn validate_architecture_stress(iterations: u32) -> ValidationReport {
    let mut report = ValidationReport::default();
    let result = chip8_architecture_stress(iterations);
    chip8_check_eq!(report, result.failures, 0);
    chip8_check!(report, result.cases >= iterations * 42);
    chip8_check!(report, result.checksum != 0);
    report
}

/// Fuzz randomized program snippets against the model invariants.
fn validate_randomized_program_fuzz(iterations: u32) -> ValidationReport {
    let mut report = ValidationReport::default();
    let mut rng = 0x5eed_f00d;
    for _ in 0..iterations {
        let mut chip = Chip8::default();
        let vx = (lcg_next(&mut rng) & 0x0f) as u16;
        let vy = (lcg_next(&mut rng) & 0x0f) as u16;
        let byte = lcg_next(&mut rng);
        let addr = 0x300 | (u16::from(lcg_next(&mut rng)) & 0x00f);
        let program = words_to_bytes(&[
            0x6000 | (vx << 8) | u16::from(byte),
            0x6100 | (vy << 8) | u16::from(byte.rotate_left(1)),
            0xa000 | addr,
            0xf01e | (vx << 8),
            0xf029 | (vy << 8),
            0xd015,
            0x120a,
        ]);
        chip.load_rom(&program);
        let draws = chip.run(7);
        chip8_check!(report, chip.pc <= 0x0fff);
        chip8_check!(report, chip.i <= 0x0fff);
        chip8_check!(report, chip.sp < 16);
        chip8_check!(report, chip.lit_pixels() <= FB_SIZE as u32);
        chip8_check_eq!(report, draws, 1);
    }
    report
}

/// Validate the video pipeline helper against frame-local expectations.
fn validate_video_pipeline() -> ValidationReport {
    let mut report = ValidationReport::default();
    let mut stream = vec![0u8; FB_SIZE * 2];
    for idx in 0..FB_SIZE {
        stream[idx * 2] = 0x80;
        stream[idx * 2 + 1] = if (idx + WIDTH) & 1 == 0 { 0xff } else { 0x00 };
    }

    let camera_fb = dcmipp_capture_ycbcr422(&stream, 0x80);
    chip8_check_eq!(report, camera_fb[0], 1);
    chip8_check_eq!(report, camera_fb[1], 0);
    chip8_check_eq!(report, camera_fb[FB_SIZE - 1], 0);

    let processed = dcmipp_postprocess(&camera_fb, true, true, true);
    chip8_check_eq!(report, processed[0], camera_fb[0]);
    chip8_check_eq!(report, processed[WIDTH + 1], camera_fb[WIDTH + 1] ^ 1);

    let dma_cfg = Dma2dConfig {
        op: Dma2dOp::Fill,
        color: 1,
        x: 8,
        y: 4,
        width: 16,
        height: 8,
        ..Dma2dConfig::default()
    };
    let dma_fb = dma2d_apply(&processed, &dma_cfg);
    chip8_check_eq!(report, dma_fb[4 * WIDTH + 8], 1);
    chip8_check_eq!(report, dma_fb[11 * WIDTH + 23], 1);
    chip8_check_eq!(
        report,
        dma_fb[12 * WIDTH + 23],
        processed[12 * WIDTH + 23]
    );
    report
}

/// Validate the microarchitecture helper contracts.
fn validate_microarchitecture_contracts() -> ValidationReport {
    let mut report = ValidationReport::default();

    for opcode in [0x00e0, 0x6001, 0x7001, 0x8123, 0xa200, 0xc1ff] {
        chip8_check!(report, prefetch_eligible(opcode));
        chip8_check!(report, !prefetch_flush_required(opcode, false));
    }

    for opcode in [0x00ee, 0x1200, 0x2200, 0x3101, 0xd125, 0xf10a] {
        chip8_check!(report, !prefetch_eligible(opcode));
        chip8_check!(report, prefetch_flush_required(opcode, false));
    }

    chip8_check!(report, prefetch_flush_required(0x6001, true));

    let bank_bits = FB_SIZE / FRAMEBUFFER_BANKS;
    for idx in 0..FB_SIZE {
        let (bank, local) = framebuffer_bank(idx);
        chip8_check!(report, bank < FRAMEBUFFER_BANKS);
        chip8_check!(report, local < bank_bits);
        chip8_check_eq!(report, bank * bank_bits + local, idx);
    }

    for mask in 0u16..=0x00ff {
        let predicates: Vec<bool> =
            (0..8).map(|idx| (mask & (1 << idx)) != 0).collect();
        chip8_check_eq!(
            report,
            prefix_count(&predicates),
            mask.count_ones() as usize
        );
    }

    chip8_check!(report, !elastic_write_visible(32, 32));
    chip8_check!(report, elastic_write_visible(32, 33));
    report
}

/// Validate every bundled ROM present in the repository.
fn validate_bundled_roms() -> ValidationReport {
    let mut report = ValidationReport::default();
    let rom_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../programs/chip8/roms");
    let mut rom_count = 0usize;

    let Ok(entries) = std::fs::read_dir(&rom_dir) else {
        record_rom_directory_error(&mut report, &rom_dir);
        return report;
    };

    for entry in entries {
        let Ok(entry) = entry else {
            report.record(false, 0x524f_4d21);
            continue;
        };
        let path = entry.path();
        if !path.is_file() {
            continue;
        }
        let Ok(rom) = std::fs::read(&path) else {
            report.record(false, path.to_string_lossy().len() as u64);
            continue;
        };
        chip8_check!(report, !rom.is_empty());
        chip8_check!(report, rom.len() <= 4096 - ROM_BASE);

        let mut chip = Chip8::default();
        chip.load_rom(&rom);
        let draws = chip.run(2500);

        chip8_check!(report, chip.pc <= 0x0fff);
        chip8_check!(report, chip.i <= 0x0fff);
        chip8_check!(report, chip.sp < 16);
        chip8_check!(report, chip.lit_pixels() <= FB_SIZE as u32);
        chip8_check!(report, !chip.halted);
        report.record(true, u64::from(draws));
        rom_count += 1;
    }

    chip8_check_eq!(report, rom_count, 23);
    report
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn smoke_boot_and_rom_packaging_are_valid() {
        validate_smoke_and_boot().assert_clean();
    }

    #[test]
    fn alu_model_is_exhaustive_against_reference() {
        validate_alu_exhaustive().assert_clean();
    }

    #[test]
    fn control_memory_video_edges_are_covered() {
        validate_control_memory_video_edges().assert_clean();
    }

    #[test]
    fn deterministic_architecture_fuzz_is_clean() {
        validate_architecture_stress(512).assert_clean();
    }

    #[test]
    fn randomized_program_fuzz_preserves_invariants() {
        validate_randomized_program_fuzz(512).assert_clean();
    }

    #[test]
    fn video_pipeline_model_matches_rtl_contract() {
        validate_video_pipeline().assert_clean();
    }

    #[test]
    fn microarchitecture_contract_model_matches_rtl_contracts() {
        validate_microarchitecture_contracts().assert_clean();
    }

    #[test]
    fn bundled_roms_run_without_state_corruption() {
        validate_bundled_roms().assert_clean();
    }

    #[test]
    fn property_pc_stays_even_and_in_range() {
        let mut report = ValidationReport::default();
        let mut rng = 0x0bad_cafe;
        for _ in 0..2048 {
            let mut chip = Chip8::default();
            let opcode = 0x6000 | u16::from(lcg_next(&mut rng));
            let _ = chip.exec(opcode);
            chip8_check!(report, chip.pc <= 0x0fff);
            chip8_check_eq!(report, chip.pc & 1, 0);
        }
        report.assert_clean();
    }

    #[test]
    fn property_stack_depth_is_bounded() {
        let mut report = ValidationReport::default();
        let mut chip = Chip8::default();
        for idx in 0..64 {
            let _ = chip.exec(0x2200 | (idx & 0x0ff));
            chip8_check!(report, chip.sp < 16);
        }
        for _ in 0..64 {
            let _ = chip.exec(0x00ee);
            chip8_check!(report, chip.sp < 16);
        }
        report.assert_clean();
    }

    #[test]
    fn property_draw_never_writes_outside_framebuffer() {
        let mut report = ValidationReport::default();
        for x in [0, 1, 62, 63, 64, 127, 255] {
            for y in [0, 1, 30, 31, 32, 127, 255] {
                let mut chip = Chip8::default();
                chip.v[0] = x;
                chip.v[1] = y;
                chip.i = 0x300;
                chip.mem[0x300] = 0xff;
                chip.mem[0x301] = 0x81;
                chip8_check!(report, chip.exec(0xd012));
                chip8_check!(report, chip.lit_pixels() <= FB_SIZE as u32);
            }
        }
        report.assert_clean();
    }

    #[test]
    fn property_timers_saturate_at_zero() {
        let mut report = ValidationReport::default();
        for start in 0u8..=u8::MAX {
            let mut chip = Chip8::default();
            chip.delay = start;
            chip.sound = start;
            for _ in 0..300 {
                let _ = chip.step();
                chip8_check!(report, chip.delay <= start);
                chip8_check!(report, chip.sound <= start);
            }
            chip8_check_eq!(report, chip.delay, 0);
            chip8_check_eq!(report, chip.sound, 0);
        }
        report.assert_clean();
    }

    #[test]
    fn property_bcd_digits_are_decimal_and_reconstruct_value() {
        let mut report = ValidationReport::default();
        for value in u8::MIN..=u8::MAX {
            let mut chip = Chip8::default();
            chip.i = 0x300;
            chip.v[3] = value;
            let _ = chip.exec(0xf333);
            let hundreds = chip.mem[0x300];
            let tens = chip.mem[0x301];
            let units = chip.mem[0x302];
            chip8_check!(report, hundreds < 10);
            chip8_check!(report, tens < 10);
            chip8_check!(report, units < 10);
            chip8_check_eq!(report, hundreds * 100 + tens * 10 + units, value);
        }
        report.assert_clean();
    }

    #[test]
    fn property_carry_and_borrow_flags_match_arithmetic() {
        let mut report = ValidationReport::default();
        for a in u8::MIN..=u8::MAX {
            for b in u8::MIN..=u8::MAX {
                let mut add_chip = Chip8::default();
                add_chip.v[1] = a;
                add_chip.v[2] = b;
                let (_, add_carry) = a.overflowing_add(b);
                let _ = add_chip.exec(0x8124);
                chip8_check_eq!(report, add_chip.v[0xf], add_carry as u8);

                let mut sub_chip = Chip8::default();
                sub_chip.v[1] = a;
                sub_chip.v[2] = b;
                let (_, sub_borrow) = a.overflowing_sub(b);
                let _ = sub_chip.exec(0x8125);
                chip8_check_eq!(report, sub_chip.v[0xf], (!sub_borrow) as u8);
            }
        }
        report.assert_clean();
    }

    #[test]
    fn full_validation_suite_has_high_case_count() {
        let report = run_validation_suite(128);
        report.assert_clean();
        assert!(report.cases > 1_000_000, "{report:?}");
    }
}
