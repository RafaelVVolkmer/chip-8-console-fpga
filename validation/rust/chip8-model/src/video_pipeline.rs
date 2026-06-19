// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
// SPDX-License-Identifier: GPL-3.0-only

use crate::constants::{FB_SIZE, HEIGHT, WIDTH};

/// Configuration for the deterministic DMA2D model.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Dma2dConfig {
    /// Whether writes are overlaid on the previous output.
    pub overlay_enable: bool,
    /// DMA2D operation to apply.
    pub op: Dma2dOp,
    /// Monochrome fill color, reduced to one bit.
    pub color: u8,
    /// Rectangle origin on the framebuffer.
    pub x: usize,
    /// Rectangle origin on the framebuffer.
    pub y: usize,
    /// Rectangle width in pixels.
    pub width: usize,
    /// Rectangle height in pixels.
    pub height: usize,
}

/// DMA2D operation kinds recognized by the model.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Dma2dOp {
    /// Mirror the input framebuffer to the output.
    Snapshot,
    /// Clear the frame to the configured color.
    Clear,
    /// Fill the selected rectangle with the configured color.
    Fill,
    /// Invert the selected frame state.
    Invert,
}

impl Default for Dma2dConfig {
    /// Create a configuration that covers the full framebuffer.
    fn default() -> Self {
        Self {
            overlay_enable: false,
            op: Dma2dOp::Snapshot,
            color: 0,
            x: 0,
            y: 0,
            width: WIDTH,
            height: HEIGHT,
        }
    }
}

/// Apply the DMA2D framebuffer transformation model.
#[must_use]
pub fn dma2d_apply(input: &[u8; FB_SIZE], cfg: &Dma2dConfig) -> [u8; FB_SIZE] {
    let mut out = [0; FB_SIZE];
    for idx in 0..FB_SIZE {
        let px = idx % WIDTH;
        let py = idx / WIDTH;
        let in_rect = px >= cfg.x
            && px < cfg.x.saturating_add(cfg.width)
            && py >= cfg.y
            && py < cfg.y.saturating_add(cfg.height);
        let base = if cfg.overlay_enable {
            out[idx]
        } else {
            input[idx]
        };
        out[idx] = match cfg.op {
            Dma2dOp::Snapshot => input[idx],
            Dma2dOp::Clear => cfg.color & 1,
            Dma2dOp::Fill if in_rect => cfg.color & 1,
            Dma2dOp::Fill => base & 1,
            Dma2dOp::Invert => (!base) & 1,
        };
    }
    out
}

/// Convert packed YCbCr422 capture bytes to the one-bit framebuffer model.
#[must_use]
pub fn dcmipp_capture_ycbcr422(bytes: &[u8], threshold: u8) -> [u8; FB_SIZE] {
    let mut out = [0; FB_SIZE];
    let mut pixel = 0usize;
    for (phase, byte) in bytes.iter().copied().enumerate() {
        if phase & 1 == 0 {
            continue;
        }
        if pixel == FB_SIZE {
            break;
        }
        out[pixel] = u8::from(byte >= threshold);
        pixel += 1;
    }
    out
}

/// Apply the DCMIPP post-processing flags to a framebuffer image.
#[must_use]
pub fn dcmipp_postprocess(
    source: &[u8; FB_SIZE],
    enable: bool,
    invert: bool,
    grid: bool,
) -> [u8; FB_SIZE] {
    let mut out = [0; FB_SIZE];
    for idx in 0..FB_SIZE {
        let x = idx % WIDTH;
        let y = idx / WIDTH;
        let grid_pixel =
            grid && (x == 0 || y == 0 || x == WIDTH - 1 || y == HEIGHT - 1);
        out[idx] = if enable {
            source[idx] ^ u8::from(invert) ^ u8::from(grid_pixel)
        } else {
            source[idx]
        };
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ycbcr422_luma_bytes_map_to_framebuffer_bits() {
        let mut stream = vec![0u8; FB_SIZE * 2];
        for idx in 0..FB_SIZE {
            stream[idx * 2] = 0x80;
            stream[idx * 2 + 1] = if idx & 1 == 0 { 0xff } else { 0x00 };
        }
        let fb = dcmipp_capture_ycbcr422(&stream, 0x80);
        assert_eq!(fb[0], 1);
        assert_eq!(fb[1], 0);
        assert_eq!(fb[FB_SIZE - 2], 1);
        assert_eq!(fb[FB_SIZE - 1], 0);
    }

    #[test]
    fn dcmipp_grid_and_invert_are_pixel_local() {
        let source = [0u8; FB_SIZE];
        let fb = dcmipp_postprocess(&source, true, true, true);
        assert_eq!(fb[0], 0);
        assert_eq!(fb[WIDTH + 1], 1);
    }

    #[test]
    fn dma2d_fill_updates_only_the_configured_rect() {
        let input = [0u8; FB_SIZE];
        let cfg = Dma2dConfig {
            op: Dma2dOp::Fill,
            color: 1,
            x: 2,
            y: 3,
            width: 4,
            height: 2,
            ..Dma2dConfig::default()
        };
        let fb = dma2d_apply(&input, &cfg);
        assert_eq!(fb[3 * WIDTH + 2], 1);
        assert_eq!(fb[4 * WIDTH + 5], 1);
        assert_eq!(fb[2 * WIDTH + 2], 0);
        assert_eq!(fb[5 * WIDTH + 5], 0);
    }
}
