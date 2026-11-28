//! The daily window Night Light is scheduled in.

/// Minutes in a day.
const MINUTES_PER_DAY: u16 = 24 * 60;

/// Parses a `HH:MM` time of day (24-hour clock) into minutes after midnight.
pub fn parse_time(value: &str) -> Option<u16> {
    let (hours, minutes) = value.trim().split_once(':')?;
    let hours: u16 = hours.parse().ok()?;
    let minutes: u16 = minutes.parse().ok()?;
    (hours < 24 && minutes < 60).then_some(hours * 60 + minutes)
}

/// Formats minutes after midnight as `HH:MM`.
pub fn format_time(minutes: u16) -> String {
    let minutes = minutes % MINUTES_PER_DAY;
    format!("{:02}:{:02}", minutes / 60, minutes % 60)
}

/// Whether `minute` (after midnight) falls in the window that starts at `from`
/// and ends at `to`, both included at the start and excluded at the end. A
/// window whose end is before its start runs past midnight; a window that
/// starts and ends at the same minute is empty.
pub fn in_window(from: u16, to: u16, minute: u16) -> bool {
    match from.cmp(&to) {
        std::cmp::Ordering::Equal => false,
        std::cmp::Ordering::Less => (from..to).contains(&minute),
        std::cmp::Ordering::Greater => minute >= from || minute < to,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_and_formats_times() {
        assert_eq!(parse_time("20:00"), Some(1200));
        assert_eq!(parse_time("06:30"), Some(390));
        assert_eq!(parse_time(" 6:05 "), Some(365));
        assert_eq!(parse_time("00:00"), Some(0));
        assert_eq!(parse_time("23:59"), Some(1439));
        assert_eq!(format_time(1200), "20:00");
        assert_eq!(format_time(365), "06:05");
    }

    #[test]
    fn rejects_malformed_times() {
        for value in ["", "24:00", "12:60", "noon", "12", "-1:00", "12:5a"] {
            assert_eq!(parse_time(value), None, "{value}");
        }
    }

    #[test]
    fn window_within_a_day() {
        // 08:00 → 17:00.
        assert!(!in_window(480, 1020, 479));
        assert!(in_window(480, 1020, 480));
        assert!(in_window(480, 1020, 1019));
        assert!(!in_window(480, 1020, 1020));
    }

    #[test]
    fn window_across_midnight() {
        // 20:00 → 06:00.
        assert!(in_window(1200, 360, 1200));
        assert!(in_window(1200, 360, 1439));
        assert!(in_window(1200, 360, 0));
        assert!(in_window(1200, 360, 359));
        assert!(!in_window(1200, 360, 360));
        assert!(!in_window(1200, 360, 720));
    }

    #[test]
    fn empty_window_is_never_active() {
        for minute in [0, 600, 1439] {
            assert!(!in_window(600, 600, minute));
        }
    }
}
