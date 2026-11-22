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

/// How long after a predicted vblank the timer acts on it. The timer never
/// acts before the vblank: a frame submitted before it would flip on that
/// vblank, and the flip would then deliver the refresh the timer already gave
/// Flutter. The margin covers the prediction's error (the flips re-anchor it
/// every frame, so it stays far below this) and lets a flip that landed on the
/// vblank report it first, with the kernel's timestamp.
const AFTER_VBLANK: Duration = Duration::from_micros(500);

#[derive(Debug, Clone)]
pub struct VsyncClock {
    interval: Duration,
    /// A vblank on the timeline: the last presented one, or an estimate while
    /// no flip has reported one yet.
    anchor: Option<Duration>,
    /// The vblank the last tick was delivered for.
    delivered: Option<Duration>,
}

impl VsyncClock {
    pub fn new(interval: Duration) -> Self {
        Self {
            interval: interval.max(Duration::from_micros(1)),
            anchor: None,
            delivered: None,
        }
    }

    pub fn interval(&self) -> Duration {
        self.interval
    }

    /// A vblank was presented at `at`: the timeline follows it from now on.
    pub fn presented(&mut self, at: Duration) {
        self.anchor = Some(at);
    }

    /// Claims the tick of `vblank`: true the first time a tick is delivered
    /// for its refresh, false when one already was. Both the flips and the
    /// timer deliver ticks; Flutter gets one per refresh whichever comes.
    pub fn claim(&mut self, vblank: Duration) -> bool {
        if self.is_delivered(vblank) {
            return false;
        }
        self.delivered = Some(vblank);
        true
    }

    /// Whether a tick was already delivered for the refresh of `vblank`. The
    /// flip's timestamp and the prediction of the same vblank differ
    /// slightly, so a refresh is anything within half a period of the
    /// delivered one; an older vblank counts as delivered too.
    fn is_delivered(&self, vblank: Duration) -> bool {
        self.delivered
            .is_some_and(|last| vblank < last + self.interval / 2)
    }

    /// The latest vblank at or before `now`. Without a presented vblank yet,
    /// `now` itself starts the timeline: an estimate until the first flip.
    pub fn latest_vblank(&mut self, now: Duration) -> Duration {
        let anchor = *self.anchor.get_or_insert(now);
        if now <= anchor {
            // The flip's timestamp can name the end of blanking, slightly
            // ahead of the moment its event is handled.
            return anchor;
        }
        anchor + self.interval * periods_between(anchor, now, self.interval)
    }

    /// The vblank the timer delivers when it fires at `now`, if any: the
    /// latest one, unless a flip is in flight (it reports its vblank itself)
    /// or that refresh was already delivered. A timer that wakes early finds
    /// only the refresh before, already delivered, and delivers nothing.
    pub fn timer_vblank(&mut self, now: Duration, flip_pending: bool) -> Option<Duration> {
        if flip_pending {
            return None;
        }
        let vblank = self.latest_vblank(now);
        (!self.is_delivered(vblank)).then_some(vblank)
    }

    /// When the timer should next act, from `now`. A vblank that passed with
    /// no tick in the first half of its period is delivered at once: a frame
    /// requested since then meets the edge a ticking timeline would have given
    /// it, and still has most of the period before its target (the next
    /// vblank). Later than that the target is too close, so the frame waits
    /// for the next vblank, just after it.
    pub fn timer_deadline(&mut self, now: Duration) -> Duration {
        let margin = AFTER_VBLANK.min(self.interval / 8);
        let vblank = self.latest_vblank(now);
        if self.is_delivered(vblank) || now >= vblank + self.interval / 2 {
            vblank + self.interval + margin
        } else {
            now.max(vblank + margin)
        }
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

    fn us(value: u64) -> Duration {
        Duration::from_micros(value)
    }

    #[test]
    fn later_vblanks_are_whole_periods_after_the_presented_one() {
        let mut clock = VsyncClock::new(ms(10));
        clock.presented(ms(1000));
        assert_eq!(clock.latest_vblank(ms(1000)), ms(1000));
        assert_eq!(clock.latest_vblank(ms(1004)), ms(1000));
        // Just short of the next edge is still the one before.
        assert_eq!(clock.latest_vblank(ms(1010) - us(1)), ms(1000));
        // Idle for a while: the phase is kept.
        assert_eq!(clock.latest_vblank(ms(1537)), ms(1530));
    }

    #[test]
    fn a_timestamp_ahead_of_now_is_the_latest_vblank() {
        let mut clock = VsyncClock::new(ms(10));
        clock.presented(ms(1000) + us(2500));
        assert_eq!(clock.latest_vblank(ms(1000)), ms(1000) + us(2500));
    }

    #[test]
    fn a_new_flip_re_anchors_the_timeline() {
        let mut clock = VsyncClock::new(ms(10));
        clock.presented(ms(1000));
        // The panel ran a little slower than the mode says.
        clock.presented(ms(1100) + us(400));
        assert_eq!(clock.latest_vblank(ms(1105)), ms(1100) + us(400));
    }

    #[test]
    fn without_a_flip_the_first_tick_starts_the_timeline() {
        let mut clock = VsyncClock::new(ms(10));
        assert_eq!(clock.timer_vblank(ms(500), false), Some(ms(500)));
        assert!(clock.claim(ms(500)));
        assert_eq!(clock.timer_deadline(ms(503)), ms(510) + us(500));
    }

    #[test]
    fn a_refresh_is_delivered_once() {
        let mut clock = VsyncClock::new(ms(10));
        // The timer delivers its prediction, then a flip names the same
        // refresh with a slightly different timestamp.
        assert!(clock.claim(ms(1000)));
        assert!(!clock.claim(ms(1000) + us(300)));
        assert!(!clock.claim(ms(1000) - us(200)));
        assert!(!clock.claim(ms(990)));
        // The next refresh, and one after an idle spell.
        assert!(clock.claim(ms(1010)));
        assert!(clock.claim(ms(1500)));
    }

    #[test]
    fn the_timer_acts_just_after_the_next_vblank_never_before() {
        let mut clock = VsyncClock::new(ms(10));
        clock.presented(ms(1000));
        assert!(clock.claim(ms(1000)));
        let deadline = clock.timer_deadline(ms(1003));
        assert_eq!(deadline, ms(1010) + us(500));
        assert!(deadline > ms(1010));
    }

    #[test]
    fn a_timer_that_wakes_early_delivers_nothing_and_waits_for_the_edge() {
        let mut clock = VsyncClock::new(ms(10));
        clock.presented(ms(1000));
        assert!(clock.claim(ms(1000)));
        // A frame submitted now would flip on 1010; the timer must not have
        // given that refresh away.
        let early = ms(1010) - us(300);
        assert_eq!(clock.timer_vblank(early, false), None);
        assert_eq!(clock.timer_deadline(early), ms(1010) + us(500));
        assert_eq!(
            clock.timer_vblank(ms(1010) + us(500), false),
            Some(ms(1010))
        );
    }

    #[test]
    fn a_flip_in_flight_reports_its_vblank_itself() {
        let mut clock = VsyncClock::new(ms(10));
        clock.presented(ms(1000));
        assert!(clock.claim(ms(1000)));
        assert_eq!(clock.timer_vblank(ms(1010) + us(500), true), None);
    }

    #[test]
    fn a_refresh_a_flip_delivered_is_not_delivered_by_the_timer() {
        let mut clock = VsyncClock::new(ms(10));
        // The flip of 1010 reported first, its timestamp a little late.
        clock.presented(ms(1010) + us(80));
        assert!(clock.claim(ms(1010) + us(80)));
        assert_eq!(clock.timer_vblank(ms(1010) + us(500), false), None);
        assert_eq!(clock.timer_deadline(ms(1010) + us(500)), ms(1020) + us(580));
    }

    #[test]
    fn a_frame_requested_after_an_untaken_vblank_meets_it_at_once() {
        let mut clock = VsyncClock::new(ms(10));
        clock.presented(ms(1000));
        assert!(clock.claim(ms(1000)));
        // Idle since; Flutter asks for a frame 4 ms after the 1050 vblank.
        let now = ms(1054);
        assert_eq!(clock.timer_deadline(now), now);
        assert_eq!(clock.timer_vblank(now, false), Some(ms(1050)));
    }

    #[test]
    fn a_frame_requested_late_in_the_period_waits_for_the_next_vblank() {
        let mut clock = VsyncClock::new(ms(10));
        clock.presented(ms(1000));
        assert!(clock.claim(ms(1000)));
        // 1050 passed untaken, but its target (1060) is 1 ms away.
        assert_eq!(clock.timer_deadline(ms(1059)), ms(1060) + us(500));
        assert_eq!(
            clock.timer_vblank(ms(1060) + us(500), false),
            Some(ms(1060))
        );
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
