//! Kernel backlight access: device discovery, the `logind` write path and the
//! `sysfs` fallback.
//!
//! `logind`'s `Session.SetBrightness` runs the write on the compositor's behalf
//! and works with the session's permissions, so it is preferred. When the
//! system bus (or the method) is unavailable the raw `/sys/class/backlight`
//! file is written directly, which works when the session already owns the
//! device (udev ACL, `video` group).

use std::fs;
use std::path::{Path, PathBuf};
use std::sync::mpsc::Receiver;

use tracing::{debug, warn};
use zbus::{Connection, Proxy};

use super::Update;

const BACKLIGHT_CLASS: &str = "/sys/class/backlight";
const LOGIN1_NAME: &str = "org.freedesktop.login1";
const LOGIN1_PATH: &str = "/org/freedesktop/login1";
const LOGIN1_MANAGER: &str = "org.freedesktop.login1.Manager";
const LOGIN1_SESSION: &str = "org.freedesktop.login1.Session";

/// One kernel backlight device.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BacklightDevice {
    /// Directory name under `/sys/class/backlight`, e.g. `intel_backlight`.
    pub name: String,
    /// The writable `brightness` attribute.
    pub path: PathBuf,
    /// Value of `brightness` that means "fully on".
    pub max_brightness: u32,
}

/// Every backlight the kernel exposes with a usable `max_brightness`.
pub fn discover() -> Vec<BacklightDevice> {
    let entries = match fs::read_dir(BACKLIGHT_CLASS) {
        Ok(entries) => entries,
        Err(error) => {
            debug!(
                ?error,
                "No backlight class; the screensaver will use the overlay"
            );
            return Vec::new();
        }
    };

    let mut devices = Vec::new();
    for entry in entries.flatten() {
        let dir = entry.path();
        let Some(name) = entry.file_name().to_str().map(str::to_owned) else {
            continue;
        };
        let max_brightness = match read_u32(&dir.join("max_brightness")) {
            Some(max) if max > 0 => max,
            _ => continue,
        };
        devices.push(BacklightDevice {
            name,
            path: dir.join("brightness"),
            max_brightness,
        });
    }
    devices
}

fn read_u32(path: &Path) -> Option<u32> {
    fs::read_to_string(path).ok()?.trim().parse().ok()
}

/// The current brightness as a fraction of each device's maximum, averaged
/// across devices. `None` when nothing is readable.
pub fn read_fraction(devices: &[BacklightDevice]) -> Option<f32> {
    let mut total = 0.0f32;
    let mut count = 0.0f32;
    for device in devices {
        if let Some(value) = read_u32(&device.path) {
            total += value as f32 / device.max_brightness as f32;
            count += 1.0;
        }
    }
    (count > 0.0).then(|| (total / count).clamp(0.0, 1.0))
}

/// Writer thread. Each message is a batch of device writes; bursts from the
/// screensaver fade (one per frame) are coalesced to the latest batch so a slow
/// `logind` round-trip can never build a backlog.
pub fn run(receiver: Receiver<Vec<Update>>) {
    let mut logind: Option<Logind> = None;
    while let Ok(mut updates) = receiver.recv() {
        while let Ok(next) = receiver.try_recv() {
            updates = next;
        }
        if logind.is_none() {
            logind = connect_logind();
        }
        apply(&logind, &updates);
    }
}

struct Logind {
    connection: Connection,
    session_path: String,
}

/// Resolve the caller's `logind` session once. `None` (no system bus, no
/// logind, or a refused lookup) is cached as "no logind" for this worker.
fn connect_logind() -> Option<Logind> {
    match zbus::block_on(async {
        let connection = Connection::system().await?;
        let manager = Proxy::new(&connection, LOGIN1_NAME, LOGIN1_PATH, LOGIN1_MANAGER).await?;
        let session_path: zbus::zvariant::OwnedObjectPath =
            manager.call("GetSession", &("auto",)).await?;
        Ok::<_, zbus::Error>(Logind {
            connection,
            session_path: session_path.to_string(),
        })
    }) {
        Ok(logind) => Some(logind),
        Err(error) => {
            debug!(
                ?error,
                "logind unavailable; writing the backlight through sysfs"
            );
            None
        }
    }
}

fn apply(logind: &Option<Logind>, updates: &[Update]) {
    for update in updates {
        if let Some(logind) = logind {
            match set_through_logind(logind, update) {
                Ok(()) => continue,
                Err(error) => {
                    debug!(
                        ?error,
                        device = %update.name,
                        "logind SetBrightness failed; falling back to sysfs"
                    );
                }
            }
        }
        if let Err(error) = set_through_sysfs(update) {
            warn!(?error, device = %update.name, "Failed to set the backlight brightness");
        }
    }
}

fn set_through_logind(logind: &Logind, update: &Update) -> zbus::Result<()> {
    zbus::block_on(async {
        let session = Proxy::new(
            &logind.connection,
            LOGIN1_NAME,
            logind.session_path.as_str(),
            LOGIN1_SESSION,
        )
        .await?;
        session
            .call_method(
                "SetBrightness",
                &("backlight", update.name.as_str(), update.value),
            )
            .await?;
        Ok(())
    })
}

fn set_through_sysfs(update: &Update) -> std::io::Result<()> {
    fs::write(&update.path, update.value.to_string())
}

#[cfg(test)]
mod tests {
    use super::read_fraction;
    use std::fs;

    #[test]
    fn read_fraction_averages_devices() {
        let dir =
            std::env::temp_dir().join(format!("veshell-backlight-test-{}", std::process::id()));
        let _ = fs::create_dir_all(&dir);
        let half = dir.join("half");
        let full = dir.join("full");
        fs::write(&half, "50\n").unwrap();
        fs::write(&full, "200\n").unwrap();

        let devices = vec![
            super::BacklightDevice {
                name: "half".to_owned(),
                path: half,
                max_brightness: 100,
            },
            super::BacklightDevice {
                name: "full".to_owned(),
                path: full,
                max_brightness: 200,
            },
        ];
        let fraction = read_fraction(&devices).unwrap();
        assert!((fraction - 0.75).abs() < f32::EPSILON);

        let _ = fs::remove_dir_all(&dir);
    }
}
