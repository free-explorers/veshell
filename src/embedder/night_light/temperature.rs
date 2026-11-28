//! Colour temperature to per-channel gains, and the gamma ramps that apply
//! them.
//!
//! A temperature is turned into the colour of a black body at that
//! temperature: its chromaticity on the Planckian locus, converted to linear
//! sRGB. The gains are that colour relative to the neutral white point, so
//! [`NEUTRAL_KELVIN`] leaves the output untouched, normalised so the strongest
//! channel stays at full scale (warming only ever removes blue and green, it
//! never dims red). They are then gamma-encoded, because the lookup table they
//! are written to works on the encoded values the outputs scan out.

/// The temperature that leaves the output untouched: sRGB's D65 white point.
pub const NEUTRAL_KELVIN: f64 = 6500.0;

/// The warmest temperature the conversion supports. The locus approximation
/// below is defined from 1667 K.
pub const MIN_KELVIN: f64 = 1700.0;

/// The encoding gamma of the scanned-out values.
const ENCODING_GAMMA: f64 = 2.2;

/// CIE 1931 chromaticity of a black body at `kelvin`, from the cubic spline
/// approximation of the Planckian locus by Kim et al. (2002), defined over
/// 1667–25000 K.
fn planckian_xy(kelvin: f64) -> (f64, f64) {
    let t = kelvin.clamp(1667.0, 25000.0);
    let x = if t <= 4000.0 {
        -0.266_123_9e9 / t.powi(3) - 0.234_358_9e6 / t.powi(2) + 0.877_695_6e3 / t + 0.179_910
    } else {
        -3.025_846_9e9 / t.powi(3) + 2.107_037_9e6 / t.powi(2) + 0.222_634_7e3 / t + 0.240_390
    };
    let y = if t <= 2222.0 {
        -1.106_381_4 * x.powi(3) - 1.348_110_20 * x.powi(2) + 2.185_558_32 * x - 0.202_196_83
    } else if t <= 4000.0 {
        -0.954_947_6 * x.powi(3) - 1.374_185_93 * x.powi(2) + 2.091_370_15 * x - 0.167_488_67
    } else {
        3.081_758_0 * x.powi(3) - 5.873_386_70 * x.powi(2) + 3.751_129_97 * x - 0.370_014_83
    };
    (x, y)
}

/// The linear sRGB colour of a black body at `kelvin`, at unit luminance.
fn linear_srgb(kelvin: f64) -> [f64; 3] {
    let (x, y) = planckian_xy(kelvin);
    let (big_x, big_y, big_z) = (x / y, 1.0, (1.0 - x - y) / y);
    [
        3.240_454_2 * big_x - 1.537_138_5 * big_y - 0.498_531_4 * big_z,
        -0.969_266_0 * big_x + 1.876_010_8 * big_y + 0.041_556_0 * big_z,
        0.055_643_4 * big_x - 0.204_025_9 * big_y + 1.057_225_2 * big_z,
    ]
}

/// The per-channel gains, in `[0, 1]` and in encoded values, that shift the
/// output from neutral to `kelvin`. `[1, 1, 1]` at [`NEUTRAL_KELVIN`] and
/// above; `kelvin` is clamped to [`MIN_KELVIN`] below.
pub fn gains(kelvin: f64) -> [f64; 3] {
    if !kelvin.is_finite() || kelvin >= NEUTRAL_KELVIN {
        return [1.0; 3];
    }
    let kelvin = kelvin.max(MIN_KELVIN);
    let white = linear_srgb(NEUTRAL_KELVIN);
    let color = linear_srgb(kelvin);
    let relative = [0, 1, 2].map(|channel| (color[channel] / white[channel]).max(0.0));
    let strongest = relative.iter().copied().fold(0.0, f64::max);
    if strongest <= 0.0 {
        return [1.0; 3];
    }
    relative.map(|gain| {
        (gain / strongest)
            .powf(1.0 / ENCODING_GAMMA)
            .clamp(0.0, 1.0)
    })
}

/// Whether `gains` leave the output untouched.
pub fn is_neutral(gains: [f64; 3]) -> bool {
    gains.iter().all(|gain| (gain - 1.0).abs() < 1e-6)
}

/// A `size`-entry lookup table for one channel, scaling it by `gain`: entry
/// `i` maps the input `i / (size - 1)` to `gain` times it, in 16-bit units.
pub fn ramp(size: usize, gain: f64) -> Vec<u16> {
    let gain = gain.clamp(0.0, 1.0);
    let last = size.saturating_sub(1).max(1) as f64;
    (0..size)
        .map(|index| (index as f64 / last * gain * f64::from(u16::MAX)).round() as u16)
        .collect()
}

/// The temperature `progress` of the way from `from` to `to` (both in kelvin),
/// interpolated in mireds (reciprocal megakelvin), in which equal steps look
/// like equal changes of tint.
pub fn interpolate(from: f64, to: f64, progress: f64) -> f64 {
    let progress = progress.clamp(0.0, 1.0);
    let (from_mired, to_mired) = (1e6 / from, 1e6 / to);
    1e6 / (from_mired + (to_mired - from_mired) * progress)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn neutral_and_above_leave_the_output_untouched() {
        assert_eq!(gains(NEUTRAL_KELVIN), [1.0; 3]);
        assert_eq!(gains(9000.0), [1.0; 3]);
        assert_eq!(gains(f64::NAN), [1.0; 3]);
    }

    #[test]
    fn just_below_neutral_is_continuous() {
        let near = gains(NEUTRAL_KELVIN - 1.0);
        for gain in near {
            assert!((gain - 1.0).abs() < 0.01, "{near:?}");
        }
    }

    #[test]
    fn warming_keeps_red_and_removes_blue_first() {
        let [red, green, blue] = gains(2700.0);
        assert_eq!(red, 1.0);
        assert!(green < 1.0 && blue < green, "{red} {green} {blue}");
        // The usual look of 2700 K: a clear orange, not a red filter.
        assert!((0.6..0.8).contains(&green), "green {green}");
        assert!((0.25..0.5).contains(&blue), "blue {blue}");
    }

    #[test]
    fn colder_temperatures_keep_more_blue_and_green() {
        let mut previous = gains(MIN_KELVIN);
        for kelvin in (1800..=6500).step_by(100) {
            let current = gains(f64::from(kelvin));
            assert!(current[1] >= previous[1] - 1e-9, "green at {kelvin}");
            assert!(current[2] >= previous[2] - 1e-9, "blue at {kelvin}");
            previous = current;
        }
    }

    #[test]
    fn below_the_minimum_clamps() {
        assert_eq!(gains(500.0), gains(MIN_KELVIN));
    }

    #[test]
    fn identity_ramp_spans_the_full_range() {
        let ramp = ramp(256, 1.0);
        assert_eq!(ramp.len(), 256);
        assert_eq!(ramp[0], 0);
        assert_eq!(ramp[255], u16::MAX);
        assert!(ramp.windows(2).all(|pair| pair[0] < pair[1]));
    }

    #[test]
    fn scaled_ramp_tops_out_at_the_gain() {
        let ramp = ramp(1024, 0.5);
        assert_eq!(ramp[1023], (f64::from(u16::MAX) * 0.5).round() as u16);
        assert!(ramp.windows(2).all(|pair| pair[0] <= pair[1]));
    }

    #[test]
    fn degenerate_ramp_sizes_do_not_panic() {
        assert!(ramp(0, 1.0).is_empty());
        assert_eq!(ramp(1, 1.0), vec![0]);
    }

    #[test]
    fn interpolation_hits_both_ends_and_moves_monotonically() {
        assert!((interpolate(6500.0, 2700.0, 0.0) - 6500.0).abs() < 1e-6);
        assert!((interpolate(6500.0, 2700.0, 1.0) - 2700.0).abs() < 1e-6);
        let mid = interpolate(6500.0, 2700.0, 0.5);
        assert!(mid < 6500.0 && mid > 2700.0);
        // Mired interpolation lingers near the warm end less than kelvin.
        assert!(mid < (6500.0 + 2700.0) / 2.0);
    }

    #[test]
    fn neutral_detection() {
        assert!(is_neutral([1.0; 3]));
        assert!(!is_neutral(gains(4000.0)));
    }
}
