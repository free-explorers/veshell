//! The pacing output's vblank timeline.
//!
//! Every page flip reports when its vblank happened (the kernel's
//! `CLOCK_MONOTONIC` timestamp). The panel then keeps refreshing at its mode's
//! exact period, so the following vblanks are the last one plus whole periods:
//! counting the periods since predicts any later vblank, without another flip
//! and without asking the kernel for vblank events. Each flip re-anchors the
//! timeline, so the prediction never drifts for long.
//!
//! Times are durations on `CLOCK_MONOTONIC`: the kernel's flip timestamps, the
//! compositor's clock and the Flutter engine's clock all use it.

use std::time::Duration;

use smithay::reexports::drm::control::{Mode, ModeFlags};

/// How far before a predicted vblank a timer may fire and still count as
/// reaching it: timers are not exact, and a tick that lands just short of the
/// edge belongs to it, not to the one before.
const EDGE_TOLERANCE: Duration = Duration::from_millis(1);

#[derive(Debug, Clone)]
pub struct VsyncClock {
    interval: Duration,
    /// A vblank on the timeline: the last presented one, or an estimate while
    /// no flip has reported one yet.
    anchor: Option<Duration>,
}

impl VsyncClock {
    pub fn new(interval: Duration) -> Self {
        Self {
            interval: interval.max(Duration::from_micros(1)),
            anchor: None,
        }
    }

    pub fn interval(&self) -> Duration {
        self.interval
    }

    /// A vblank was presented at `at`: the timeline follows it from now on.
    pub fn presented(&mut self, at: Duration) {
        self.anchor = Some(at);
    }

    /// The latest vblank at or before `now`. Without a presented vblank yet,
    /// `now` itself starts the timeline: an estimate until the first flip.
    pub fn latest_vblank(&mut self, now: Duration) -> Duration {
        let anchor = *self.anchor.get_or_insert(now);
        let tolerance = EDGE_TOLERANCE.min(self.interval / 4);
        let reach = now + tolerance;
        if reach <= anchor {
            // The flip's timestamp can name the end of blanking, slightly
            // ahead of the moment its event is handled.
            return anchor;
        }
        anchor + self.interval * periods_between(anchor, reach, self.interval)
    }

    /// The first vblank after the latest one at or before `now`.
    pub fn next_vblank(&mut self, now: Duration) -> Duration {
        self.latest_vblank(now) + self.interval
    }
}

/// Whole periods of `interval` from `from` to `to`.
fn periods_between(from: Duration, to: Duration, interval: Duration) -> u32 {
    let periods = (to - from).as_nanos() / interval.as_nanos().max(1);
    u32::try_from(periods).unwrap_or(u32::MAX)
}

/// One refresh of `mode`: its total pixels over its pixel clock. The refresh
/// rate a mode advertises is rounded (59.951 Hz reads as 60 Hz), and a
/// prediction built on it drifts a little every period.
pub fn mode_interval(mode: &Mode) -> Option<Duration> {
    if mode
        .flags()
        .intersects(ModeFlags::INTERLACE | ModeFlags::DBLSCAN)
        || mode.vscan() > 1
    {
        return None;
    }
    interval_from_timings(mode.clock(), mode.hsync().2, mode.vsync().2)
}

fn interval_from_timings(
    clock_khz: u32,
    horizontal_total: u16,
    vertical_total: u16,
) -> Option<Duration> {
    if clock_khz == 0 || horizontal_total == 0 || vertical_total == 0 {
        return None;
    }
    let nanos =
        u64::from(horizontal_total) * u64::from(vertical_total) * 1_000_000 / u64::from(clock_khz);
    Some(Duration::from_nanos(nanos))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ms(value: u64) -> Duration {
        Duration::from_millis(value)
    }

    #[test]
    fn later_vblanks_are_whole_periods_after_the_presented_one() {
        let mut clock = VsyncClock::new(ms(10));
        clock.presented(ms(1000));
        assert_eq!(clock.latest_vblank(ms(1000)), ms(1000));
        assert_eq!(clock.latest_vblank(ms(1004)), ms(1000));
        assert_eq!(clock.next_vblank(ms(1004)), ms(1010));
        // Idle for a while: the phase is kept.
        assert_eq!(clock.latest_vblank(ms(1537)), ms(1530));
        assert_eq!(clock.next_vblank(ms(1537)), ms(1540));
    }

    #[test]
    fn a_timer_just_short_of_the_edge_reaches_it() {
        let mut clock = VsyncClock::new(ms(10));
        clock.presented(ms(1000));
        let early = ms(1010) - Duration::from_micros(300);
        assert_eq!(clock.latest_vblank(early), ms(1010));
    }

    #[test]
    fn a_timestamp_ahead_of_now_is_the_latest_vblank() {
        let mut clock = VsyncClock::new(ms(10));
        clock.presented(ms(1000) + Duration::from_micros(2500));
        assert_eq!(
            clock.latest_vblank(ms(1000)),
            ms(1000) + Duration::from_micros(2500)
        );
    }

    #[test]
    fn a_new_flip_re_anchors_the_timeline() {
        let mut clock = VsyncClock::new(ms(10));
        clock.presented(ms(1000));
        // The panel ran a little slower than the mode says.
        clock.presented(ms(1100) + Duration::from_micros(400));
        assert_eq!(
            clock.next_vblank(ms(1105)),
            ms(1110) + Duration::from_micros(400)
        );
    }

    #[test]
    fn without_a_flip_the_first_tick_starts_the_timeline() {
        let mut clock = VsyncClock::new(ms(10));
        assert_eq!(clock.latest_vblank(ms(500)), ms(500));
        assert_eq!(clock.next_vblank(ms(503)), ms(510));
    }

    #[test]
    fn the_interval_comes_from_the_mode_totals() {
        // 2560x1440 at 59.951 Hz (CVT reduced blanking).
        assert_eq!(
            interval_from_timings(241_500, 2720, 1481),
            Some(Duration::from_nanos(16_680_414))
        );
        // 3840x2160 at 120 Hz.
        assert_eq!(
            interval_from_timings(1_185_840, 3660, 2700),
            Some(Duration::from_nanos(8_333_333))
        );
        assert_eq!(interval_from_timings(0, 2720, 1481), None);
    }
}
