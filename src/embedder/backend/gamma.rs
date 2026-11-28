//! The CRTC colour lookup table Night Light writes (see
//! [`crate::backend::Backend::set_color_gains`]).
//!
//! An atomic device takes the table as the CRTC's `GAMMA_LUT` blob, and a
//! neutral table is no table at all (the blob is cleared, so the hardware
//! bypasses the lookup). A device without it takes the legacy gamma ramp.
//!
//! Smithay's commits never name the CRTC's colour properties, so a table stays
//! in place across its page flips and modesets. A table is committed on its
//! own, and only while no flip is in flight on the CRTC.
//!
//! A change while the session runs (Night Light fading) is committed like a
//! page flip: non-blocking, with a flip event. It shows at the next vblank,
//! which the backend handles as any flip's, holding rendering on that output
//! until then. A blocking commit would instead stall the event loop until that
//! vblank, a whole frame per output. One-off writes (a new output, session
//! activation, handing the device over) block: they happen once, and a CRTC
//! that is off takes no flip event.

use std::io;
use std::os::fd::AsFd;

use smithay::backend::drm::DrmSurface;
use smithay::reexports::drm::control::atomic::AtomicModeReq;
use smithay::reexports::drm::control::{property, AtomicCommitFlags, Device as _};
use tracing::{debug, warn};

use crate::night_light::temperature;

/// How a CRTC takes its colour lookup table.
#[derive(Debug, Clone, Copy)]
enum Control {
    /// The atomic `GAMMA_LUT` property, `size` entries.
    Atomic {
        property: property::Handle,
        size: usize,
    },
    /// The legacy gamma ramp, `size` entries.
    Legacy { size: usize },
}

/// How [`GammaTable::commit`] writes a table.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CommitMode {
    /// Non-blocking, completing at the next vblank with a page-flip event
    /// (falls back to [`Self::Blocking`] on a CRTC that is off).
    Flip,
    /// Blocking: the table shows when the call returns.
    Blocking,
}

/// What a successful [`GammaTable::commit`] left in flight.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Committed {
    /// The table shows already.
    Shown,
    /// The table shows at the CRTC's next vblank, reported as a page flip:
    /// no other commit may go to the CRTC until then.
    AtNextVblank,
}

/// One CRTC's lookup table and what it still has to show.
#[derive(Debug)]
pub struct GammaTable {
    control: Control,
    /// The gains the hardware shows, or `None` when unknown (a new output, or
    /// one another DRM master may have changed while the session was away).
    applied: Option<[f64; 3]>,
}

impl GammaTable {
    /// Finds how `surface`'s CRTC takes a lookup table, or `None` when it has
    /// none (some virtual and USB display drivers).
    pub fn probe(surface: &DrmSurface, atomic: bool) -> Option<Self> {
        let crtc = surface.crtc();
        let control = atomic
            .then(|| atomic_control(surface))
            .flatten()
            .or_else(|| legacy_size(surface, crtc).map(|size| Control::Legacy { size }))?;
        debug!(?crtc, ?control, "Night Light lookup table");
        Some(Self {
            control,
            applied: None,
        })
    }

    /// Whether the hardware may not show `gains` yet.
    pub fn needs(&self, gains: [f64; 3]) -> bool {
        self.applied != Some(gains)
    }

    /// Forgets what the hardware shows, so the next [`Self::commit`] writes the
    /// table again.
    pub fn invalidate(&mut self) {
        self.applied = None;
    }

    /// Writes `gains` to the hardware. Meant for a CRTC with no page flip in
    /// flight: a [`CommitMode::Flip`] commit would then fail as busy, and a
    /// blocking one waits for the flip.
    ///
    /// A busy CRTC (`EBUSY`) leaves the table to write again at the next
    /// vblank. Any other failure is recorded as written, so it is reported
    /// once per change instead of at every vblank; [`Self::invalidate`]
    /// retries it (on session activation).
    pub fn commit(
        &mut self,
        surface: &DrmSurface,
        gains: [f64; 3],
        mode: CommitMode,
    ) -> io::Result<Committed> {
        let crtc = surface.crtc();
        let result = match self.control {
            Control::Atomic { property, size } => {
                match commit_atomic(surface, crtc, property, size, gains, mode) {
                    // A driver may reject the atomic table and still take the
                    // legacy ramp: switch over for good when it does. Other
                    // errors (no DRM master, a busy CRTC) are transient.
                    Err(err) if err.raw_os_error() == Some(libc::EINVAL) => {
                        match legacy_size(surface, crtc) {
                            Some(size) => {
                                warn!(?crtc, "GAMMA_LUT rejected ({err}); using the gamma ramp");
                                self.control = Control::Legacy { size };
                                commit_legacy(surface, crtc, size, gains)
                            }
                            None => Err(err),
                        }
                    }
                    result => result,
                }
            }
            Control::Legacy { size } => commit_legacy(surface, crtc, size, gains),
        };
        if !matches!(&result, Err(err) if err.raw_os_error() == Some(libc::EBUSY)) {
            self.applied = Some(gains);
        }
        result
    }
}

/// The CRTC's legacy gamma ramp size, when it has one.
fn legacy_size(
    surface: &DrmSurface,
    crtc: smithay::reexports::drm::control::crtc::Handle,
) -> Option<usize> {
    let size = surface.get_crtc(crtc).ok()?.gamma_length() as usize;
    (size > 0).then_some(size)
}

/// The CRTC's `GAMMA_LUT` property and its `GAMMA_LUT_SIZE`, when it has both.
fn atomic_control(surface: &DrmSurface) -> Option<Control> {
    let properties = surface.get_properties(surface.crtc()).ok()?;
    let mut lut = None;
    let mut size = None;
    for (&handle, &value) in properties.iter() {
        let Ok(info) = surface.get_property(handle) else {
            continue;
        };
        match info.name().to_bytes() {
            b"GAMMA_LUT" => lut = Some(handle),
            b"GAMMA_LUT_SIZE" => size = Some(value as usize),
            _ => {}
        }
    }
    match (lut, size) {
        (Some(property), Some(size)) if size > 0 => Some(Control::Atomic { property, size }),
        _ => None,
    }
}

fn commit_atomic(
    surface: &DrmSurface,
    crtc: smithay::reexports::drm::control::crtc::Handle,
    property: property::Handle,
    size: usize,
    gains: [f64; 3],
    mode: CommitMode,
) -> io::Result<Committed> {
    // No table for neutral: the hardware bypasses the lookup, exactly the
    // identity.
    let blob = if temperature::is_neutral(gains) {
        None
    } else {
        let mut bytes = lut_bytes(size, gains);
        Some(drm_ffi::mode::create_property_blob(surface.as_fd(), &mut bytes)?.blob_id)
    };
    let request = || {
        let mut request = AtomicModeReq::new();
        let value = property::Value::Blob(blob.map_or(0, u64::from));
        request.add_property(crtc, property, value);
        request
    };
    let result = match mode {
        CommitMode::Flip => surface
            .atomic_commit(
                AtomicCommitFlags::NONBLOCK | AtomicCommitFlags::PAGE_FLIP_EVENT,
                request(),
            )
            .map(|()| Committed::AtNextVblank)
            .or_else(|err| {
                // A CRTC that is off (a blanked screen) has no vblank to send
                // the event at: it takes the table at once instead.
                if err.raw_os_error() == Some(libc::EINVAL) {
                    surface
                        .atomic_commit(AtomicCommitFlags::empty(), request())
                        .map(|()| Committed::Shown)
                } else {
                    Err(err)
                }
            }),
        CommitMode::Blocking => surface
            .atomic_commit(AtomicCommitFlags::empty(), request())
            .map(|()| Committed::Shown),
    };
    // The CRTC holds its own reference to a blob it shows: ours can go.
    if let Some(blob) = blob {
        if let Err(err) = surface.destroy_property_blob(u64::from(blob)) {
            debug!("Failed to release a GAMMA_LUT blob: {err}");
        }
    }
    result
}

fn commit_legacy(
    surface: &DrmSurface,
    crtc: smithay::reexports::drm::control::crtc::Handle,
    size: usize,
    gains: [f64; 3],
) -> io::Result<Committed> {
    let [red, green, blue] = gains.map(|gain| temperature::ramp(size, gain));
    // The legacy ioctl always blocks.
    surface
        .set_gamma(crtc, &red, &green, &blue)
        .map(|()| Committed::Shown)
}

/// A `GAMMA_LUT` blob: `size` `struct drm_color_lut` entries (red, green,
/// blue, reserved; 16 bits each, native endian).
fn lut_bytes(size: usize, gains: [f64; 3]) -> Vec<u8> {
    let [red, green, blue] = gains.map(|gain| temperature::ramp(size, gain));
    let mut bytes = Vec::with_capacity(size * 8);
    for index in 0..size {
        for value in [red[index], green[index], blue[index], 0] {
            bytes.extend_from_slice(&value.to_ne_bytes());
        }
    }
    bytes
}

#[cfg(test)]
mod tests {
    use super::lut_bytes;

    #[test]
    fn lut_blob_packs_drm_color_lut_entries() {
        let bytes = lut_bytes(4, [1.0, 0.5, 0.0]);
        assert_eq!(bytes.len(), 4 * 8);
        let entry = |index: usize| -> [u16; 4] {
            let chunk = &bytes[index * 8..index * 8 + 8];
            [0, 1, 2, 3]
                .map(|channel| u16::from_ne_bytes([chunk[channel * 2], chunk[channel * 2 + 1]]))
        };
        assert_eq!(entry(0), [0, 0, 0, 0]);
        assert_eq!(entry(3), [u16::MAX, 32768, 0, 0]);
    }
}
