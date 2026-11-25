use std::collections::{BTreeMap, HashMap, HashSet, VecDeque};
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use super::{get_binary_name_from_pid, get_flatpack_app_id_from_pid, get_snap_app_id_from_pid};

/// Shells a terminal may run as its interactive child.
///
/// This is used only to locate the terminal's shell and its working directory.
/// The allowlist deciding which *foreground programs* may be replayed lives in
/// the Dart terminal-resume policy.
const SHELL_NAMES: &[&str] = &[
    "sh", "bash", "zsh", "fish", "dash", "ksh", "ksh93", "mksh", "ash", "nu", "elvish", "xonsh",
    "tcsh", "csh",
];

/// The survival wrapper a resumed terminal runs its program through.
///
/// `resume_launch_plan.dart` builds:
///
/// ```text
/// /bin/sh -c '<this script>' <shell> <title> <program> <args...>
/// ```
///
/// so the terminal stays at an interactive prompt after the program exits. The
/// wrapper is a non-interactive shell sitting in front of the program: without
/// unwrapping it, a second capture would report `/bin/sh` as the terminal's
/// shell and lose the foreground program, and resuming again would open a
/// fresh shell. Keep this string in sync with `_shellSurvivalScript`.
const RESUME_WRAPPER_SCRIPT: &str =
    r#"if [ -n "$1" ]; then printf "\033]0;%s\007" "$1"; fi; shift; "$@"; exec "$0""#;

/// Basenames of the loaders a Wine (and so Proton) process runs as.
///
/// Wine rewrites a process's argv to its Windows command line
/// (`C:\...\Game.exe`), so `cmdline` alone names a path no Linux launcher
/// can run; `/proc/<pid>/exe` still points at the loader. Older builds start
/// through the preloaders, newer (WoW64) ones run `wine` directly.
const WINE_LOADER_NAMES: &[&str] = &["wine-preloader", "wine64-preloader", "wine", "wine64"];

/// Prefixes of the variables that configure how Wine runs a program.
///
/// Runners (Lutris, Bottles) set the prefix, DLL overrides, sync primitives
/// and translation layers per game; a relaunch through a bare `wine` needs them
/// back to run the program the same way.
const WINE_ENVIRONMENT_PREFIXES: &[&str] = &["WINE", "DXVK_", "VKD3D_", "STAGING_"];

/// Variables Wine sets for its own children, which describe the running
/// session rather than its configuration.
const WINE_INTERNAL_VARIABLES: &[&str] = &[
    "WINELOADER",
    "WINELOADERNOEXEC",
    "WINEPRELOADRESERVE",
    "WINESERVERSOCKET",
];

/// The wrapper shape used before the terminal title was seeded on resume.
///
/// Kept readable so a fallback launch from an old persisted argv still
/// unwraps to the program it replays.
const LEGACY_RESUME_WRAPPER_SCRIPT: &str = r#""$@"; exec "$0""#;

/// Process-level facts read from `/proc` for a surface client pid.
///
/// The cgroup is a property of the process, not of the window, so it is
/// delivered keyed by pid instead of being duplicated on every [`MetaWindow`].
/// The raw sandbox/binary identities are kept as-is (rather than only their
/// desktop-entry-resolved form) so the signal source stays available.
///
/// `cmdline`, `cwd` and `exe` describe the window's own process. `terminal` is
/// present only when the process has a shell descendant (a terminal emulator):
/// it carries the shell and its foreground job, which is what a tile resumes.
///
/// A snapshot is taken at window creation, refreshed when the pid changes,
/// when the window is mapped and when its title changes, plus on demand from
/// the shell (`get_process_info`).
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
    pub cmdline: Vec<String>,
    pub cwd: Option<String>,
    pub exe: Option<String>,
    pub terminal: Option<TerminalInfo>,
    /// Present only for a Wine process (Proton included).
    pub wine: Option<WineInfo>,
}

/// Wine/Proton context of a process, read from its initial environment.
///
/// Proton is told apart from plain Wine (Lutris, Bottles, a bare `wine`) by
/// the Steam compatibility variables: only a Steam launch through a compat
/// tool sets `STEAM_COMPAT_DATA_PATH`.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct WineInfo {
    /// `WINEPREFIX`, when set (Proton sets it to `<compat data>/pfx`).
    pub prefix: Option<String>,
    /// The Steam app id the game was launched as (`steam://rungameid/<id>`),
    /// present only when Steam itself launched it.
    pub steam_app_id: Option<String>,
    /// `STEAM_COMPAT_DATA_PATH`: the per-game compat data; set only by Proton.
    pub compat_data_path: Option<String>,
    /// `STEAM_COMPAT_TOOL_PATHS`: the Proton install, then the runtime(s).
    pub compat_tool_paths: Vec<String>,
    /// The Wine configuration variables of the process (`WINE*`, `DXVK_*`,
    /// `VKD3D_*`, `STAGING_*`), `WINEPREFIX` included, minus Wine's own
    /// session variables. Sorted, so an unchanged capture compares equal.
    pub environment: BTreeMap<String, String>,
}

/// One process in the terminal's shell/foreground chain.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ProcessDescriptor {
    pub pid: i32,
    pub exe: Option<String>,
    pub cmdline: Vec<String>,
    pub cwd: Option<String>,
}

/// Terminal-specific context: the shell and its foreground job.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct TerminalInfo {
    pub shell: Option<ProcessDescriptor>,
    /// The process group the terminal currently has in the foreground.
    ///
    /// Only reported when it differs from the shell's own group, so a shell
    /// sitting at the prompt never masquerades as a resumable program.
    pub foreground: Option<ProcessDescriptor>,
}

impl ProcessInfo {
    pub fn for_pid(pid: i32) -> Self {
        Self::for_pid_in(Path::new("/proc"), pid)
    }

    /// Testable variant rooted at [proc_root] (`/proc` in production).
    pub fn for_pid_in(proc_root: &Path, pid: i32) -> Self {
        let (_, flatpak_id) = get_flatpack_app_id_from_pid(pid);
        let (_, snap_id) = get_snap_app_id_from_pid(pid);
        let cmdline = read_cmdline(proc_root, pid);
        let exe = read_exe(proc_root, pid);
        let wine = wine_info(proc_root, pid, exe.as_deref(), &cmdline);
        Self {
            pid,
            cgroup: get_cgroup_from_pid(pid),
            flatpak_id,
            snap_id,
            binary_name: get_binary_name_from_pid(pid),
            cmdline,
            cwd: read_cwd(proc_root, pid),
            exe,
            terminal: terminal_info(proc_root, pid),
            wine,
        }
    }
}

/// Wine context of [pid], or `None` when it is not a Wine process.
///
/// The environment is read only once the loader identifies a Wine process, so
/// ordinary clients never have theirs parsed. When the `exe` link cannot be
/// read, a Windows-looking argv[0] stands in for it.
fn wine_info(
    proc_root: &Path,
    pid: i32,
    exe: Option<&str>,
    cmdline: &[String],
) -> Option<WineInfo> {
    let is_wine = match exe {
        Some(exe) => is_wine_loader(exe),
        None => cmdline
            .first()
            .is_some_and(|program| program.to_ascii_lowercase().ends_with(".exe")),
    };
    if !is_wine {
        return None;
    }
    let environment = read_environ(proc_root, pid);
    let variable = |name: &str| {
        environment
            .get(name)
            .filter(|value| !value.is_empty())
            .cloned()
    };
    let compat_data_path = variable("STEAM_COMPAT_DATA_PATH");
    // Only Steam's own launch makes the game a Steam game: umu-launcher
    // (Heroic, Lutris) runs Proton outside Steam with the same compat
    // variables, and sets `SteamAppId` to the store id it looks game fixes up
    // with, which the user may not own on Steam.
    let steam_app_id = steam_launch(proc_root, pid).and_then(|launch_app_id| {
        // Non-Steam shortcuts report `SteamAppId=0`; their id is
        // `SteamGameId`. The launcher's own `AppId=`, then the compat data
        // directory (named after the app id), are the last resorts.
        variable("SteamAppId")
            .filter(|id| id != "0")
            .or_else(|| variable("SteamGameId").filter(|id| id != "0"))
            .or(launch_app_id)
            .or_else(|| {
                compat_data_path.as_deref().and_then(|path| {
                    Path::new(path)
                        .file_name()
                        .and_then(|name| name.to_str())
                        .filter(|name| is_app_id(name))
                        .map(str::to_owned)
                })
            })
    });
    Some(WineInfo {
        prefix: variable("WINEPREFIX"),
        steam_app_id,
        compat_data_path,
        compat_tool_paths: variable("STEAM_COMPAT_TOOL_PATHS")
            .map(|paths| {
                paths
                    .split(':')
                    .filter(|path| !path.is_empty())
                    .map(str::to_owned)
                    .collect()
            })
            .unwrap_or_default(),
        environment: environment
            .iter()
            .filter(|(name, _)| is_wine_configuration(name))
            .map(|(name, value)| (name.clone(), value.clone()))
            .collect(),
    })
}

/// How deep [steam_launch] looks for Steam's launcher: a game sits a handful
/// of processes under it (launch wrapper, Proton script, runtime container).
const STEAM_LAUNCH_SEARCH_DEPTH: usize = 32;

/// Whether an ancestor of [pid] is Steam's game launcher, and the `AppId=` it
/// was given.
///
/// Steam starts every game, Proton or native, under
/// `reaper SteamLaunch AppId=<id> -- ...`. `/proc` shows host pids, so the
/// chain is intact across the runtime's container.
fn steam_launch(proc_root: &Path, pid: i32) -> Option<Option<String>> {
    let mut current = pid;
    for _ in 0..STEAM_LAUNCH_SEARCH_DEPTH {
        let parent = parse_stat_file(proc_root, current)?.ppid;
        if parent <= 1 {
            return None;
        }
        let cmdline = read_cmdline(proc_root, parent);
        let is_reaper = cmdline
            .first()
            .is_some_and(|program| Path::new(program).file_name() == Some("reaper".as_ref()));
        if is_reaper && cmdline.iter().any(|argument| argument == "SteamLaunch") {
            return Some(
                cmdline
                    .iter()
                    .take_while(|argument| *argument != "--")
                    .find_map(|argument| argument.strip_prefix("AppId="))
                    .filter(|id| is_app_id(id) && *id != "0")
                    .map(str::to_owned),
            );
        }
        current = parent;
    }
    None
}

fn is_app_id(value: &str) -> bool {
    !value.is_empty() && value.bytes().all(|byte| byte.is_ascii_digit())
}

fn is_wine_configuration(name: &str) -> bool {
    WINE_ENVIRONMENT_PREFIXES
        .iter()
        .any(|prefix| name.starts_with(prefix))
        && !WINE_INTERNAL_VARIABLES.contains(&name)
}

fn is_wine_loader(exe: &str) -> bool {
    Path::new(exe)
        .file_name()
        .and_then(|name| name.to_str())
        .is_some_and(|name| WINE_LOADER_NAMES.contains(&name))
}

/// The initial environment of [pid] (`/proc/<pid>/environ`), empty when
/// unreadable.
fn read_environ(proc_root: &Path, pid: i32) -> HashMap<String, String> {
    let Ok(bytes) = std::fs::read(proc_root.join(pid.to_string()).join("environ")) else {
        return HashMap::new();
    };
    bytes
        .split(|byte| *byte == 0)
        .filter_map(|entry| {
            let entry = String::from_utf8_lossy(entry);
            let (name, value) = entry.split_once('=')?;
            Some((name.to_owned(), value.to_owned()))
        })
        .collect()
}

fn terminal_info(proc_root: &Path, pid: i32) -> Option<TerminalInfo> {
    if pid <= 0 {
        return None;
    }

    let shell = find_shell(proc_root, pid)?;
    if let Some(wrapper) = resume_wrapper(&shell) {
        return Some(unwrap_resume_wrapper(proc_root, &shell, &wrapper));
    }
    let stats = parse_stat_file(proc_root, shell.pid)?;
    let foreground = foreground_process(proc_root, &shell, stats.pgrp, stats.tpgid);
    let shell = process_descriptor(proc_root, shell.pid)?;
    Some(TerminalInfo {
        shell: Some(shell),
        foreground,
    })
}

/// The target shell and program of a resume survival wrapper.
struct ResumeWrapper<'a> {
    shell: &'a str,
    program: &'a str,
    arguments: &'a [String],
}

/// Recognizes the wrapper [`RESUME_WRAPPER_SCRIPT`] builds.
///
/// The script itself is the marker: it is the only `sh -c` command Veshell
/// passes to a terminal, so an unrelated shell command is never mistaken for
/// one and unwrapped.
fn resume_wrapper(node: &ProcessNode) -> Option<ResumeWrapper<'_>> {
    let args = &node.cmdline;
    if args.len() < 5 || args[1] != "-c" {
        return None;
    }
    // The current wrapper carries the title to seed before the program; the
    // legacy one starts the program at index 4.
    let program_index = match args[2].as_str() {
        RESUME_WRAPPER_SCRIPT => 5,
        LEGACY_RESUME_WRAPPER_SCRIPT => 4,
        _ => return None,
    };
    let shell = args.get(3)?;
    if !is_shell_path(shell) {
        return None;
    }
    let program = args.get(program_index)?;
    Some(ResumeWrapper {
        shell,
        program,
        arguments: args.get(program_index + 1..).unwrap_or_default(),
    })
}

/// Reports the shell and program behind a survival wrapper.
///
/// The wrapper has not exec'd the shell yet (the program is still running), so
/// the shell is described from the wrapper's argv. The program is the wrapper's
/// first descendant; when it has already exited, its saved argv keeps the
/// context resumable until the wrapper execs the shell.
fn unwrap_resume_wrapper(
    proc_root: &Path,
    wrapper_node: &ProcessNode,
    wrapper: &ResumeWrapper<'_>,
) -> TerminalInfo {
    let cwd = read_cwd(proc_root, wrapper_node.pid);
    let shell = ProcessDescriptor {
        // The shell is not a live process yet: the wrapper execs it once the
        // program exits. The descriptor still carries what a resume needs.
        pid: 0,
        exe: Some(wrapper.shell.to_string()),
        cmdline: vec![wrapper.shell.to_string()],
        cwd: cwd.clone(),
    };
    // Breadth-first descendants start with the direct child, which is the
    // program the wrapper launched.
    let foreground = descendants(proc_root, wrapper_node.pid)
        .first()
        .and_then(|child| process_descriptor(proc_root, child.pid))
        .unwrap_or_else(|| ProcessDescriptor {
            pid: 0,
            exe: Some(wrapper.program.to_string()),
            cmdline: std::iter::once(wrapper.program.to_string())
                .chain(wrapper.arguments.iter().cloned())
                .collect(),
            cwd,
        });
    TerminalInfo {
        shell: Some(shell),
        foreground: Some(foreground),
    }
}

fn foreground_process(
    proc_root: &Path,
    shell: &ProcessNode,
    shell_pgrp: i32,
    tpgid: i32,
) -> Option<ProcessDescriptor> {
    if tpgid <= 0 || tpgid == shell_pgrp || tpgid == shell.pid {
        return None;
    }

    // The foreground job's group leader is the natural command to replay.
    if is_descendant(proc_root, tpgid, shell.pid) {
        if let Some(descriptor) = process_descriptor(proc_root, tpgid) {
            return Some(descriptor);
        }
    }

    // The leader can exit while its group keeps the terminal. Pick the
    // lowest-pid descendant that belongs to the foreground group; anything not
    // rooted in the shell is ignored.
    let mut candidates = descendants(proc_root, shell.pid)
        .into_iter()
        .filter_map(|node| {
            let stats = parse_stat_file(proc_root, node.pid)?;
            (stats.pgrp == tpgid).then_some(node.pid)
        })
        .collect::<Vec<_>>();
    candidates.sort_unstable();
    candidates
        .into_iter()
        .find_map(|pid| process_descriptor(proc_root, pid))
}

fn find_shell(proc_root: &Path, pid: i32) -> Option<ProcessNode> {
    let own = process_node(proc_root, pid)?;
    if is_shell(&own) {
        return Some(own);
    }
    descendants(proc_root, pid).into_iter().find(is_shell)
}

fn is_shell(node: &ProcessNode) -> bool {
    node.exe
        .as_deref()
        .or_else(|| node.cmdline.first().map(String::as_str))
        .is_some_and(is_shell_path)
}

fn is_shell_path(path: &str) -> bool {
    let Some(command) = Path::new(path).file_name().and_then(|name| name.to_str()) else {
        return false;
    };
    // Strip a leading `-` used by login shells (`-bash`).
    SHELL_NAMES.contains(&command.trim_start_matches('-'))
}

fn is_descendant(proc_root: &Path, pid: i32, ancestor: i32) -> bool {
    if pid == ancestor {
        return true;
    }
    descendants(proc_root, ancestor)
        .into_iter()
        .any(|node| node.pid == pid)
}

#[derive(Clone, Debug)]
struct ProcessNode {
    pid: i32,
    ppid: i32,
    exe: Option<String>,
    cmdline: Vec<String>,
}

fn process_node(proc_root: &Path, pid: i32) -> Option<ProcessNode> {
    let stats = parse_stat_file(proc_root, pid)?;
    Some(ProcessNode {
        pid,
        ppid: stats.ppid,
        exe: read_exe(proc_root, pid),
        cmdline: read_cmdline(proc_root, pid),
    })
}

/// Breadth-first descendants of [pid], excluding the root.
///
/// Prefers the kernel's per-process `children` file, so a normal application
/// with no shell descendant costs one open instead of a `/proc` scan. Falls
/// back to the full process table when that interface is unavailable.
fn descendants(proc_root: &Path, pid: i32) -> Vec<ProcessNode> {
    if let Some(result) = descendants_from_children(proc_root, pid) {
        return result;
    }

    let table = process_table(proc_root);
    let mut children: HashMap<i32, Vec<i32>> = HashMap::new();
    for node in table.values() {
        children.entry(node.ppid).or_default().push(node.pid);
    }

    let mut visited = HashSet::new();
    let mut queue = VecDeque::from([pid]);
    let mut result = Vec::new();
    while let Some(parent) = queue.pop_front() {
        let Some(child_ids) = children.get(&parent) else {
            continue;
        };
        for &child in child_ids {
            if !visited.insert(child) {
                continue;
            }
            if let Some(node) = table.get(&child) {
                result.push(node.clone());
                queue.push_back(child);
            }
        }
    }
    result
}

fn descendants_from_children(proc_root: &Path, pid: i32) -> Option<Vec<ProcessNode>> {
    let mut visited = HashSet::new();
    let mut queue = VecDeque::from([pid]);
    let mut result = Vec::new();
    while let Some(parent) = queue.pop_front() {
        for child in read_children(proc_root, parent)? {
            if !visited.insert(child) {
                continue;
            }
            let node = process_node(proc_root, child)?;
            result.push(node);
            queue.push_back(child);
        }
    }
    Some(result)
}

fn read_children(proc_root: &Path, pid: i32) -> Option<Vec<i32>> {
    let contents = std::fs::read_to_string(
        proc_root
            .join(pid.to_string())
            .join("task")
            .join(pid.to_string())
            .join("children"),
    )
    .ok()?;
    Some(
        contents
            .split_whitespace()
            .filter_map(|child| child.parse().ok())
            .collect(),
    )
}

/// The process table under [proc_root], keyed by pid.
///
/// Reads the children file first when it is available, which keeps the common
/// non-terminal case cheap, but always returns a full table for the
/// descendant/foreground checks (they are only done for terminal windows).
fn process_table(proc_root: &Path) -> HashMap<i32, ProcessNode> {
    let mut table = HashMap::new();
    let Ok(entries) = std::fs::read_dir(proc_root) else {
        return table;
    };
    for entry in entries.flatten() {
        let Some(name) = entry.file_name().to_str().map(str::to_owned) else {
            continue;
        };
        let Ok(pid) = name.parse::<i32>() else {
            continue;
        };
        if let Some(node) = process_node(proc_root, pid) {
            table.insert(pid, node);
        }
    }
    table
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct ProcStat {
    ppid: i32,
    pgrp: i32,
    tpgid: i32,
}

fn parse_stat_file(proc_root: &Path, pid: i32) -> Option<ProcStat> {
    let contents = std::fs::read_to_string(proc_root.join(pid.to_string()).join("stat")).ok()?;
    parse_stat(&contents)
}

/// Parses the subset of `/proc/<pid>/stat` needed for terminal detection.
///
/// `comm` is wrapped in parentheses and may itself contain spaces and
/// parentheses, so parsing starts after the *last* `)`.
fn parse_stat(contents: &str) -> Option<ProcStat> {
    let close = contents.rfind(')')?;
    let fields = contents[close + 1..].split_whitespace().collect::<Vec<_>>();
    // state ppid pgrp session tty_nr tpgid
    Some(ProcStat {
        ppid: fields.get(1)?.parse().ok()?,
        pgrp: fields.get(2)?.parse().ok()?,
        tpgid: fields.get(5)?.parse().ok()?,
    })
}

fn process_descriptor(proc_root: &Path, pid: i32) -> Option<ProcessDescriptor> {
    if pid <= 0 {
        return None;
    }
    Some(ProcessDescriptor {
        pid,
        exe: read_exe(proc_root, pid),
        cmdline: read_cmdline(proc_root, pid),
        cwd: read_cwd(proc_root, pid),
    })
}

fn read_cmdline(proc_root: &Path, pid: i32) -> Vec<String> {
    let Ok(bytes) = std::fs::read(proc_root.join(pid.to_string()).join("cmdline")) else {
        return Vec::new();
    };
    bytes
        .split(|byte| *byte == 0)
        .filter(|part| !part.is_empty())
        .map(|part| String::from_utf8_lossy(part).into_owned())
        .collect()
}

fn read_cwd(proc_root: &Path, pid: i32) -> Option<String> {
    read_link(proc_root.join(pid.to_string()).join("cwd"))
}

fn read_exe(proc_root: &Path, pid: i32) -> Option<String> {
    read_link(proc_root.join(pid.to_string()).join("exe"))
}

fn read_link(path: PathBuf) -> Option<String> {
    let target = std::fs::read_link(path).ok()?;
    Some(
        target
            .to_string_lossy()
            .trim_end_matches(" (deleted)")
            .to_string(),
    )
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

#[cfg(test)]
mod tests {
    use super::*;

    fn proc_root() -> PathBuf {
        let root = std::env::temp_dir().join(format!("veshell-proc-{}", uuid::Uuid::new_v4()));
        std::fs::create_dir_all(&root).unwrap();
        root
    }

    fn add_process(root: &Path, pid: i32, ppid: i32, comm: &str, args: &[&str], cwd: &str) {
        let dir = root.join(pid.to_string());
        std::fs::create_dir_all(dir.join("task").join(pid.to_string())).unwrap();
        std::fs::write(
            dir.join("stat"),
            format!("{pid} ({comm}) S {ppid} {pid} {pid} 34816 {pid} 4194304"),
        )
        .unwrap();
        let mut cmdline = Vec::new();
        for arg in args {
            cmdline.extend_from_slice(arg.as_bytes());
            cmdline.push(0);
        }
        std::fs::write(dir.join("cmdline"), cmdline).unwrap();
        std::os::unix::fs::symlink(cwd, dir.join("cwd")).unwrap();
        std::os::unix::fs::symlink(format!("/usr/bin/{comm}"), dir.join("exe")).unwrap();
    }

    fn add_foreground_group(
        root: &Path,
        shell_parent: i32,
        shell_pid: i32,
        program_pid: i32,
        program: &str,
    ) {
        let shell_dir = root.join(shell_pid.to_string());
        std::fs::write(
            shell_dir.join("stat"),
            format!(
                "{shell_pid} (bash) S {shell_parent} {shell_pid} {shell_pid} 34816 {program_pid} 0"
            ),
        )
        .unwrap();
        let program_dir = root.join(program_pid.to_string());
        std::fs::create_dir_all(program_dir.join("task").join(program_pid.to_string())).unwrap();
        std::fs::write(
            program_dir.join("stat"),
            format!("{program_pid} ({program}) S {shell_pid} {program_pid} {shell_pid} 34816 {program_pid} 0"),
        )
        .unwrap();
        std::fs::write(
            program_dir.join("cmdline"),
            format!("{program}\0file.txt\0"),
        )
        .unwrap();
        std::os::unix::fs::symlink("/home/user/project", program_dir.join("cwd")).unwrap();
        std::os::unix::fs::symlink(format!("/usr/bin/{program}"), program_dir.join("exe")).unwrap();
    }

    #[test]
    fn stat_parser_handles_spaces_and_parentheses_in_comm() {
        let stat = parse_stat("123 (my (weird) app) S 1 2 3 34816 4 0").unwrap();
        assert_eq!(stat.ppid, 1);
        assert_eq!(stat.pgrp, 2);
        assert_eq!(stat.tpgid, 4);
    }

    #[test]
    fn finds_shell_working_directory_without_foreground_program() {
        let root = proc_root();
        add_process(&root, 100, 1, "foot", &["foot"], "/home/user");
        add_process(&root, 101, 100, "bash", &["bash"], "/home/user/src");

        let info = ProcessInfo::for_pid_in(&root, 100);
        let terminal = info.terminal.expect("terminal info");

        assert_eq!(terminal.shell.as_ref().unwrap().pid, 101);
        assert_eq!(
            terminal.shell.as_ref().unwrap().cwd.as_deref(),
            Some("/home/user/src")
        );
        assert!(terminal.foreground.is_none());

        std::fs::remove_dir_all(root).ok();
    }

    #[test]
    fn reports_foreground_job_of_the_shell() {
        let root = proc_root();
        add_process(&root, 100, 1, "alacritty", &["alacritty"], "/home/user");
        add_process(&root, 101, 100, "bash", &["bash"], "/home/user/src");
        add_foreground_group(&root, 100, 101, 200, "nvim");

        let info = ProcessInfo::for_pid_in(&root, 100);
        let terminal = info.terminal.expect("terminal info");
        let foreground = terminal.foreground.expect("foreground program");

        assert_eq!(foreground.pid, 200);
        assert_eq!(foreground.cmdline, vec!["nvim", "file.txt"]);
        assert_eq!(foreground.cwd.as_deref(), Some("/home/user/project"));

        std::fs::remove_dir_all(root).ok();
    }

    #[test]
    fn unwraps_the_resume_survival_wrapper() {
        let root = proc_root();
        add_process(&root, 100, 1, "alacritty", &["alacritty"], "/home/user");
        add_process(
            &root,
            101,
            100,
            "sh",
            &[
                "/bin/sh",
                "-c",
                RESUME_WRAPPER_SCRIPT,
                "/usr/bin/zsh",
                "htop",
                "/usr/bin/htop",
                "-d",
                "10",
            ],
            "/home/user/src",
        );
        add_process(
            &root,
            200,
            101,
            "htop",
            &["htop", "-d", "10"],
            "/home/user/src",
        );

        let terminal = ProcessInfo::for_pid_in(&root, 100)
            .terminal
            .expect("terminal info");
        let shell = terminal.shell.expect("shell behind the wrapper");
        assert_eq!(shell.exe.as_deref(), Some("/usr/bin/zsh"));
        assert_eq!(shell.cmdline, vec!["/usr/bin/zsh"]);
        assert_eq!(shell.cwd.as_deref(), Some("/home/user/src"));

        let foreground = terminal.foreground.expect("replayed program");
        assert_eq!(foreground.pid, 200);
        assert_eq!(foreground.exe.as_deref(), Some("/usr/bin/htop"));
        assert_eq!(foreground.cmdline, vec!["htop", "-d", "10"]);

        std::fs::remove_dir_all(root).ok();
    }

    #[test]
    fn unwraps_a_wrapper_whose_program_has_not_started() {
        let root = proc_root();
        add_process(&root, 100, 1, "alacritty", &["alacritty"], "/home/user");
        add_process(
            &root,
            101,
            100,
            "sh",
            &[
                "/bin/sh",
                "-c",
                RESUME_WRAPPER_SCRIPT,
                "/usr/bin/zsh",
                "htop",
                "/usr/bin/htop",
                "-d",
                "10",
            ],
            "/home/user/src",
        );

        let terminal = ProcessInfo::for_pid_in(&root, 100)
            .terminal
            .expect("terminal info");
        assert_eq!(
            terminal.shell.expect("shell").exe.as_deref(),
            Some("/usr/bin/zsh")
        );
        let foreground = terminal.foreground.expect("program from the wrapper");
        assert_eq!(foreground.exe.as_deref(), Some("/usr/bin/htop"));
        assert_eq!(foreground.cmdline, vec!["/usr/bin/htop", "-d", "10"]);
        assert_eq!(foreground.cwd.as_deref(), Some("/home/user/src"));

        std::fs::remove_dir_all(root).ok();
    }

    #[test]
    fn unwraps_the_legacy_resume_wrapper() {
        let root = proc_root();
        add_process(&root, 100, 1, "alacritty", &["alacritty"], "/home/user");
        add_process(
            &root,
            101,
            100,
            "sh",
            &[
                "/bin/sh",
                "-c",
                LEGACY_RESUME_WRAPPER_SCRIPT,
                "/usr/bin/zsh",
                "/usr/bin/htop",
            ],
            "/home/user/src",
        );
        add_process(&root, 200, 101, "htop", &["htop"], "/home/user/src");

        let terminal = ProcessInfo::for_pid_in(&root, 100)
            .terminal
            .expect("terminal info");
        assert_eq!(
            terminal.shell.expect("shell").exe.as_deref(),
            Some("/usr/bin/zsh")
        );
        assert_eq!(
            terminal.foreground.expect("legacy program").cmdline,
            vec!["htop"]
        );

        std::fs::remove_dir_all(root).ok();
    }

    #[test]
    fn falls_back_to_a_group_member_when_the_leader_exited() {
        let root = proc_root();
        add_process(&root, 100, 1, "foot", &["foot"], "/home/user");
        add_process(&root, 101, 100, "bash", &["bash"], "/home/user/src");
        add_process(
            &root,
            201,
            101,
            "nvim",
            &["nvim", "file.txt"],
            "/home/user/src",
        );
        std::fs::write(
            root.join("101").join("stat"),
            "101 (bash) S 100 101 101 34816 200 0",
        )
        .unwrap();
        std::fs::write(
            root.join("201").join("stat"),
            "201 (nvim) S 101 200 101 34816 200 0",
        )
        .unwrap();

        let terminal = ProcessInfo::for_pid_in(&root, 100)
            .terminal
            .expect("terminal info");
        let foreground = terminal.foreground.expect("foreground group member");

        assert_eq!(foreground.pid, 201);
        assert_eq!(foreground.cmdline, vec!["nvim", "file.txt"]);

        std::fs::remove_dir_all(root).ok();
    }

    #[test]
    fn a_shell_at_the_prompt_is_not_a_foreground_program() {
        let root = proc_root();
        add_process(&root, 100, 1, "foot", &["foot"], "/home/user");
        add_process(&root, 101, 100, "bash", &["bash"], "/home/user/src");

        let terminal = ProcessInfo::for_pid_in(&root, 100)
            .terminal
            .expect("terminal info");
        assert!(terminal.foreground.is_none());

        std::fs::remove_dir_all(root).ok();
    }

    #[test]
    fn a_window_without_children_has_no_terminal_context() {
        let root = proc_root();
        add_process(&root, 100, 1, "firefox", &["firefox"], "/home/user");

        let info = ProcessInfo::for_pid_in(&root, 100);
        assert!(info.terminal.is_none());
        assert_eq!(info.cmdline, vec!["firefox"]);
        assert_eq!(info.cwd.as_deref(), Some("/home/user"));

        std::fs::remove_dir_all(root).ok();
    }

    /// Parent of every test Wine process; a Steam launch puts `reaper` there.
    const STEAM_LAUNCHER_PID: i32 = 50;

    fn add_steam_launcher(root: &Path, app_id: &str) {
        let reaper = "/home/user/.steam/steam/ubuntu12_32/reaper";
        let app_id = format!("AppId={app_id}");
        add_process(
            root,
            STEAM_LAUNCHER_PID,
            40,
            "reaper",
            &[
                reaper,
                "SteamLaunch",
                &app_id,
                "--",
                "/home/user/.steam/steam/ubuntu12_32/steam-launch-wrapper",
            ],
            "/home/user",
        );
    }

    fn add_wine_process(root: &Path, pid: i32, exe: &str, args: &[&str], environ: &[&str]) {
        let dir = root.join(pid.to_string());
        std::fs::create_dir_all(dir.join("task").join(pid.to_string())).unwrap();
        std::fs::write(
            dir.join("stat"),
            format!("{pid} (Game.exe) S {STEAM_LAUNCHER_PID} {pid} {pid} 0 -1 0"),
        )
        .unwrap();
        std::fs::write(
            dir.join("cmdline"),
            args.iter()
                .map(|arg| format!("{arg}\0"))
                .collect::<String>(),
        )
        .unwrap();
        std::fs::write(
            dir.join("environ"),
            environ
                .iter()
                .map(|var| format!("{var}\0"))
                .collect::<String>(),
        )
        .unwrap();
        std::os::unix::fs::symlink("/home/user/games/game", dir.join("cwd")).unwrap();
        std::os::unix::fs::symlink(exe, dir.join("exe")).unwrap();
    }

    #[test]
    fn reports_the_proton_context_of_a_steam_game() {
        let root = proc_root();
        add_steam_launcher(&root, "1091500");
        let proton = "/home/user/.steam/steam/steamapps/common/Proton 9.0 (Beta)";
        let compat = "/home/user/.steam/steam/steamapps/compatdata/1091500";
        let tools = format!("STEAM_COMPAT_TOOL_PATHS={proton}:/home/user/.steam/steam/steamapps/common/SteamLinuxRuntime_sniper");
        add_wine_process(
            &root,
            100,
            &format!("{proton}/files/bin/wine64-preloader"),
            &["Z:\\home\\user\\games\\game\\Game.exe"],
            &[
                "HOME=/home/user",
                "SteamAppId=1091500",
                &format!("STEAM_COMPAT_DATA_PATH={compat}"),
                &format!("WINEPREFIX={compat}/pfx"),
                &tools,
            ],
        );

        let info = ProcessInfo::for_pid_in(&root, 100);
        let wine = info.wine.expect("wine context");
        assert_eq!(wine.steam_app_id.as_deref(), Some("1091500"));
        assert_eq!(wine.compat_data_path.as_deref(), Some(compat));
        assert_eq!(wine.prefix, Some(format!("{compat}/pfx")));
        assert_eq!(wine.compat_tool_paths.len(), 2);
        assert_eq!(wine.compat_tool_paths[0], proton);
        assert!(info.terminal.is_none());

        std::fs::remove_dir_all(root).ok();
    }

    #[test]
    fn a_non_steam_shortcut_takes_its_game_id() {
        let root = proc_root();
        add_steam_launcher(&root, "3141592653");
        add_wine_process(
            &root,
            100,
            "/opt/proton/files/bin/wine",
            &["C:\\Game.exe"],
            &[
                "SteamAppId=0",
                "SteamGameId=12345678901234567890",
                "STEAM_COMPAT_DATA_PATH=/home/user/compatdata/3141592653",
            ],
        );

        let wine = ProcessInfo::for_pid_in(&root, 100)
            .wine
            .expect("wine context");
        assert_eq!(wine.steam_app_id.as_deref(), Some("12345678901234567890"));

        std::fs::remove_dir_all(root).ok();
    }

    #[test]
    fn the_compat_data_directory_names_the_app_when_no_id_is_set() {
        let root = proc_root();
        add_steam_launcher(&root, "0");
        add_wine_process(
            &root,
            100,
            "/opt/proton/files/bin/wine64",
            &["C:\\Game.exe"],
            &["STEAM_COMPAT_DATA_PATH=/home/user/compatdata/570/"],
        );

        let wine = ProcessInfo::for_pid_in(&root, 100)
            .wine
            .expect("wine context");
        assert_eq!(wine.steam_app_id.as_deref(), Some("570"));

        std::fs::remove_dir_all(root).ok();
    }

    #[test]
    fn the_steam_launcher_names_the_app_when_the_environment_does_not() {
        let root = proc_root();
        add_steam_launcher(&root, "1245620");
        add_wine_process(
            &root,
            100,
            "/opt/proton/files/bin/wine64-preloader",
            &["C:\\Game.exe"],
            &["STEAM_COMPAT_DATA_PATH=/home/user/compatdata/elden"],
        );

        let wine = ProcessInfo::for_pid_in(&root, 100)
            .wine
            .expect("wine context");
        assert_eq!(wine.steam_app_id.as_deref(), Some("1245620"));

        std::fs::remove_dir_all(root).ok();
    }

    #[test]
    fn proton_run_by_umu_outside_steam_is_no_steam_game() {
        let root = proc_root();
        add_wine_process(
            &root,
            100,
            "/home/user/.local/share/umu/GE-Proton/files/bin/wine64-preloader",
            &["Z:\\home\\user\\Games\\Heroic\\Game\\Game.exe"],
            &[
                "GAMEID=umu-1091500",
                "SteamAppId=1091500",
                "SteamGameId=1091500",
                "STEAM_COMPAT_DATA_PATH=/home/user/Games/Heroic/Prefixes/Game",
                "WINEPREFIX=/home/user/Games/Heroic/Prefixes/Game",
            ],
        );

        let wine = ProcessInfo::for_pid_in(&root, 100)
            .wine
            .expect("wine context");
        assert!(wine.steam_app_id.is_none());
        assert!(wine.compat_data_path.is_some());

        std::fs::remove_dir_all(root).ok();
    }

    #[test]
    fn plain_wine_has_a_prefix_but_no_steam_context() {
        let root = proc_root();
        add_wine_process(
            &root,
            100,
            "/usr/bin/wine-preloader",
            &["C:\\Program Files\\App\\App.exe"],
            &[
                "WINEPREFIX=/home/user/.wine",
                "WINEDLLOVERRIDES=d3d11=n",
                "WINEFSYNC=1",
                "DXVK_HUD=fps",
                "WINELOADERNOEXEC=1",
                "WINESERVERSOCKET=3",
                "HOME=/home/user",
            ],
        );

        let wine = ProcessInfo::for_pid_in(&root, 100)
            .wine
            .expect("wine context");
        assert_eq!(
            wine.environment.keys().collect::<Vec<_>>(),
            ["DXVK_HUD", "WINEDLLOVERRIDES", "WINEFSYNC", "WINEPREFIX"],
        );
        assert_eq!(wine.prefix.as_deref(), Some("/home/user/.wine"));
        assert!(wine.compat_data_path.is_none());
        assert!(wine.steam_app_id.is_none());
        assert!(wine.compat_tool_paths.is_empty());

        std::fs::remove_dir_all(root).ok();
    }

    #[test]
    fn a_native_program_has_no_wine_context_even_with_steam_variables() {
        let root = proc_root();
        add_wine_process(
            &root,
            100,
            "/home/user/games/native/game.x86_64",
            &["./game.x86_64"],
            &[
                "SteamAppId=440",
                "STEAM_COMPAT_DATA_PATH=/home/user/compatdata/440",
            ],
        );

        assert!(ProcessInfo::for_pid_in(&root, 100).wine.is_none());

        std::fs::remove_dir_all(root).ok();
    }

    #[test]
    fn a_windows_argv_stands_in_for_an_unreadable_exe() {
        assert!(wine_info(
            Path::new("/nonexistent"),
            1,
            None,
            &["C:\\GAME.EXE".to_string()]
        )
        .is_some());
        assert!(wine_info(
            Path::new("/nonexistent"),
            1,
            None,
            &["/usr/bin/firefox".to_string()]
        )
        .is_none());
    }

    #[test]
    fn a_bad_pid_degrades_to_empty_facts() {
        let root = proc_root();
        let info = ProcessInfo::for_pid_in(&root, 999);
        assert!(info.cmdline.is_empty());
        assert!(info.cwd.is_none());
        assert!(info.terminal.is_none());
        assert!(info.wine.is_none());
        std::fs::remove_dir_all(root).ok();
    }
}
