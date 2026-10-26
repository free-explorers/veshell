use std::collections::{HashMap, HashSet, VecDeque};
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
        Self {
            pid,
            cgroup: get_cgroup_from_pid(pid),
            flatpak_id,
            snap_id,
            binary_name: get_binary_name_from_pid(pid),
            cmdline: read_cmdline(proc_root, pid),
            cwd: read_cwd(proc_root, pid),
            exe: read_exe(proc_root, pid),
            terminal: terminal_info(proc_root, pid),
        }
    }
}

fn terminal_info(proc_root: &Path, pid: i32) -> Option<TerminalInfo> {
    if pid <= 0 {
        return None;
    }

    let shell = find_shell(proc_root, pid)?;
    let stats = parse_stat_file(proc_root, shell.pid)?;
    let foreground = foreground_process(proc_root, &shell, stats.pgrp, stats.tpgid);
    let shell = process_descriptor(proc_root, shell.pid)?;
    Some(TerminalInfo {
        shell: Some(shell),
        foreground,
    })
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
    let command = node
        .exe
        .as_deref()
        .and_then(|exe| Path::new(exe).file_name())
        .and_then(|name| name.to_str())
        .or_else(|| node.cmdline.first().map(String::as_str))
        .and_then(|command| Path::new(command).file_name())
        .and_then(|name| name.to_str())
        .unwrap_or_default();
    // Strip a leading `-` used by login shells (`-bash`).
    let command = command.trim_start_matches('-');
    SHELL_NAMES.contains(&command)
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

    #[test]
    fn a_bad_pid_degrades_to_empty_facts() {
        let root = proc_root();
        let info = ProcessInfo::for_pid_in(&root, 999);
        assert!(info.cmdline.is_empty());
        assert!(info.cwd.is_none());
        assert!(info.terminal.is_none());
        std::fs::remove_dir_all(root).ok();
    }
}
