import 'package:path/path.dart' as path;
import 'package:shell/application/model/desktop_exec.dart';

/// How to append a command to a terminal emulator's own argv.
class TerminalEmulator {
  const TerminalEmulator({
    required this.name,
    required this.commandArguments,
    List<String> Function(String? workingDirectory)? commandSuffix,
  }) : _commandSuffix = commandSuffix;

  final String name;

  /// Arguments that make the terminal run the following argv.
  ///
  /// Often `-e` or `--`; wezterm needs `start --` and optionally `--cwd`.
  final List<String> Function(String? workingDirectory) commandArguments;

  final List<String> Function(String? workingDirectory)? _commandSuffix;

  /// Like [commandArguments], but for a custom exec whose base command already
  /// contains the terminal's subcommand (`wezterm start`).
  List<String> suffixArguments(String? workingDirectory) =>
      (_commandSuffix ?? commandArguments)(workingDirectory);

  /// Whether [tokens] already start a program after the terminal.
  bool hasCommandArguments(List<String> tokens) => tokens.any(
    (token) =>
        token == '-e' ||
        token == '--' ||
        token == '-x' ||
        token == '--command' ||
        token == '--execute',
  );
}

final Map<String, TerminalEmulator> _emulators = {
  'alacritty': _flagEmulator('alacritty', '--working-directory'),
  'xterm': TerminalEmulator(
    name: 'xterm',
    commandArguments: (_) => const ['-e'],
  ),
  'urxvt': TerminalEmulator(
    name: 'urxvt',
    commandArguments: (_) => const ['-e'],
  ),
  'st': TerminalEmulator(name: 'st', commandArguments: (_) => const ['-e']),
  'sakura': TerminalEmulator(
    name: 'sakura',
    commandArguments: (_) => const ['-e'],
  ),
  'ghostty': _flagEmulator('ghostty', '--working-directory'),
  'konsole': _flagEmulator('konsole', '--workdir'),
  'xfce4-terminal': _flagEmulator('xfce4-terminal', null, separator: ['-x']),
  'foot': _flagEmulator('foot', '--working-directory', separator: ['--']),
  'footclient': _flagEmulator('foot', '--working-directory', separator: ['--']),
  'kitty': _flagEmulator('kitty', '--directory', separator: ['--']),
  'gnome-terminal': _flagEmulator(
    'gnome-terminal',
    '--working-directory',
    separator: ['--'],
  ),
  'kgx': _flagEmulator('kgx', '--working-directory', separator: ['--']),
  'wezterm': TerminalEmulator(
    name: 'wezterm',
    commandArguments: (workingDirectory) => [
      'start',
      if (workingDirectory != null) ...['--cwd', workingDirectory],
      '--',
    ],
    commandSuffix: (workingDirectory) => [
      if (workingDirectory != null) ...['--cwd', workingDirectory],
      '--',
    ],
  ),
};

/// Common desktop-application ids for terminal emulators.
const _terminalAppIds = <String, String>{
  'org.gnome.terminal': 'gnome-terminal',
  'org.gnome.console': 'kgx',
  'org.gnome.kgx': 'kgx',
  'org.kde.konsole': 'konsole',
  'org.wezfurlong.wezterm': 'wezterm',
  'com.mitchellh.ghostty': 'ghostty',
  'io.alacritty': 'alacritty',
  'org.alacritty': 'alacritty',
};

/// Finds the terminal emulator behind a tile.
///
/// Detection is deliberately conservative: captured executable first, then the
/// desktop `Exec` command (skipping `env`/`flatpak run`/`snap run` wrappers),
/// then the app id. An unknown terminal yields null and the resume launch opens
/// its normal shell, without guessing a `-e`-style syntax.
TerminalEmulator? terminalEmulatorFor({
  String? executable,
  String? execTemplate,
  String? appId,
  List<String> capturedArgv = const [],
}) {
  final candidates = <String>{
    if (executable != null) path.basename(executable),
    if (capturedArgv.isNotEmpty) path.basename(capturedArgv.first),
    if (execTemplate != null)
      ..._execCandidates(DesktopExec.parse(execTemplate).tokens),
    if (appId != null) path.basename(appId).toLowerCase(),
  };

  for (final candidate in candidates) {
    final normalized = _normalize(candidate);
    final key = _terminalAppIds[normalized] ?? normalized;
    final emulator = _emulators[key];
    if (emulator != null) {
      return emulator;
    }
  }
  return null;
}

List<String> _execCandidates(List<String> tokens) {
  final candidates = <String>[];
  var index = 0;
  while (index < tokens.length) {
    final token = tokens[index];
    if (token == 'env') {
      index++;
      while (index < tokens.length && tokens[index].startsWith('-')) {
        index++;
      }
      // Skip `NAME=value` assignments after env.
      while (index < tokens.length &&
          tokens[index].contains('=') &&
          !tokens[index].contains('/')) {
        index++;
      }
      continue;
    }
    if (token == 'flatpak' || token == 'snap') {
      index++;
      if (index < tokens.length && tokens[index] == 'run') {
        index++;
      }
      continue;
    }
    if (token == 'sh' || token == 'bash' || token == '-c') {
      // A shell wrapper hides the real command; relying on the other
      // candidates (captured executable/app id) is safer.
      break;
    }
    candidates.add(path.basename(token));
    index++;
  }
  return candidates;
}

String _normalize(String value) =>
    value.toLowerCase().replaceFirst(RegExp(r'^-'), '');

TerminalEmulator _flagEmulator(
  String name,
  String? workingDirectoryFlag, {
  List<String> separator = const ['-e'],
}) {
  return TerminalEmulator(
    name: name,
    commandArguments: (workingDirectory) => [
      if (workingDirectoryFlag != null && workingDirectory != null) ...[
        workingDirectoryFlag,
        workingDirectory,
      ],
      ...separator,
    ],
  );
}
