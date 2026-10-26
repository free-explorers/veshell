import 'dart:io';

import 'package:path/path.dart' as path;

/// Programs that are safe to replay inside a resumed terminal.
///
/// This is an explicit allowlist: anything not named here is never replayed.
/// The list is intentionally limited to read-only/monitoring tools, editors,
/// pagers, file managers and multiplexers. Package managers, shells, remote
/// sessions, builds, interpreters and arbitrary scripts are excluded.
const terminalProgramAllowlist = <String>{
  // Editors
  'nvim',
  'vim',
  'vi',
  'nano',
  'micro',
  'helix',
  'hx',
  'emacs',
  // Pagers/viewers
  'less',
  'more',
  'most',
  'bat',
  'batcat',
  // System monitors
  'htop',
  'btop',
  'top',
  'atop',
  'iotop',
  'iftop',
  'nethogs',
  'ncdu',
  'duf',
  // File managers
  'ranger',
  'nnn',
  'lf',
  'mc',
  'vifm',
  'yazi',
  // Multiplexers (their internal sessions are not restored)
  'tmux',
  'screen',
  'zellij',
  // Manual pages
  'man',
  'info',
};

/// Commands that must never be replayed, even if the allowlist changes.
///
/// This is a defence-in-depth check for names whose side effects are too large
/// to be inferred from their arguments.
const terminalProgramDenylist = <String>{
  'sh',
  'bash',
  'zsh',
  'fish',
  'dash',
  'ksh',
  'mksh',
  'nu',
  'elvish',
  'xonsh',
  'ssh',
  'scp',
  'sftp',
  'sudo',
  'doas',
  'su',
  'pkexec',
  'apt',
  'apt-get',
  'dnf',
  'pacman',
  'zypper',
  'yum',
  'make',
  'ninja',
  'cmake',
  'cargo',
  'npm',
  'yarn',
  'pnpm',
  'python',
  'python3',
  'node',
  'ruby',
  'perl',
};

/// Shells that may be used as the terminal's surviving shell.
const terminalShellAllowlist = <String>{
  'sh',
  'bash',
  'zsh',
  'fish',
  'dash',
  'ksh',
  'ksh93',
  'mksh',
  'ash',
  'nu',
  'elvish',
  'xonsh',
  'tcsh',
  'csh',
};

/// Whether [program] (a path or bare command) is an allowlisted foreground
/// program.
bool isSafeTerminalProgram(String program) {
  final name = _basename(program);
  if (name.isEmpty) {
    return false;
  }
  return terminalProgramAllowlist.contains(name) &&
      !terminalProgramDenylist.contains(name);
}

/// Whether [shell] is a shell we can safely leave the user in.
bool isTerminalShell(String shell) =>
    terminalShellAllowlist.contains(_basename(shell));

/// Resolves a program to an executable path, or null when it is missing.
///
/// Absolute paths are checked directly. Bare names are looked up in `PATH`.
/// [workingDirectory] resolves relative paths that contain a slash.
String? resolveExecutablePath(
  String program, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool Function(String path)? isExecutable,
}) {
  final executable = isExecutable ?? isExecutableFile;
  if (program.isEmpty) {
    return null;
  }
  if (path.isAbsolute(program)) {
    return executable(program) ? program : null;
  }
  if (program.contains('/')) {
    final resolved = workingDirectory == null
        ? program
        : path.join(workingDirectory, program);
    return executable(resolved) ? resolved : null;
  }

  final variables = environment ?? Platform.environment;
  for (final directory in (variables['PATH'] ?? '').split(':')) {
    if (directory.isEmpty) {
      continue;
    }
    final candidate = path.join(directory, program);
    if (executable(candidate)) {
      return candidate;
    }
  }
  return null;
}

/// Whether [path] is a regular file with an execute bit set.
bool isExecutableFile(String path) {
  final stat = FileStat.statSync(path);
  if (stat.type != FileSystemEntityType.file) {
    return false;
  }
  // chmod(1) permission bits for owner/group/other execute.
  return stat.mode & 0x49 != 0;
}

String _basename(String program) =>
    path.basename(program).replaceFirst(RegExp(r'^-'), '');
