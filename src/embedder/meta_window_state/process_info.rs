use serde::{Deserialize, Serialize};

use super::{get_binary_name_from_pid, get_flatpack_app_id_from_pid, get_snap_app_id_from_pid};

/// Process-level facts read from `/proc` for a surface client pid.
///
/// The cgroup is a property of the process, not of the window, so it is
/// delivered keyed by pid instead of being duplicated on every [`MetaWindow`].
/// The raw sandbox/binary identities are kept as-is (rather than only their
/// desktop-entry-resolved form) so the signal source stays available.
///
/// A snapshot is taken at window creation, refreshed when the pid changes, and
/// refreshed again when the window is mapped.
///
/// [`MetaWindow`]: super::meta_window::MetaWindow
#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct ProcessInfo {
    pub pid: i32,
    pub cgroup: Option<String>,
    pub flatpak_id: Option<String>,
    pub snap_id: Option<String>,
    pub binary_name: Option<String>,
}

impl ProcessInfo {
    pub fn for_pid(pid: i32) -> Self {
        let (_, flatpak_id) = get_flatpack_app_id_from_pid(pid);
        let (_, snap_id) = get_snap_app_id_from_pid(pid);
        Self {
            pid,
            cgroup: get_cgroup_from_pid(pid),
            flatpak_id,
            snap_id,
            binary_name: get_binary_name_from_pid(pid),
        }
    }
}

/// Unified cgroup path of `pid` (v2 `0::/path` line), or `None` when
/// unreadable or empty.
fn get_cgroup_from_pid(pid: i32) -> Option<String> {
    if pid == 0 {
        return None;
    }
    let contents = std::fs::read_to_string(format!("/proc/{pid}/cgroup")).ok()?;
    contents
        .lines()
        .find_map(|line| {
            line.split_once("::")
                .map(|(_, path)| path.trim().to_string())
        })
        .filter(|path| !path.is_empty())
}
