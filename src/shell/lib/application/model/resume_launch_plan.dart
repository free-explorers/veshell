import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:shell/application/model/desktop_exec.dart';
import 'package:shell/application/model/launch_config.serializable.dart';
import 'package:shell/application/model/terminal_emulator.dart';
import 'package:shell/application/model/terminal_program_policy.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/window/model/resume_context.serializable.dart';

/// A resume launch ready to hand to `AppLaunch`, plus the context it resolved.
class ResumeLaunchPlan {
  const ResumeLaunchPlan({required this.config, required this.context});

  final LaunchConfig config;
  final ResumeContext context;
}

/// Builds the launch configuration for a persistent tile.
///
/// Order of resolution:
///
/// 1. a custom exec keeps its shell command;
/// 2. the desktop entry's `Exec` template is parsed and its document field
///    codes are filled from the saved context;
/// 3. when the entry is gone, the saved argv/executable is the fallback.
///
/// The working directory is the saved one when it still exists, then home,
/// then the compositor's cwd. Missing documents and missing executables are
/// dropped, never fatal.
ResumeLaunchPlan? buildResumeLaunchPlan({
  required ResumeContext? context,
  String? customExec,
  String? execTemplate,
  String? entryName,
  String? entryIcon,
  String? homeDirectory,
  String? appId,
  Map<String, String>? environment,
  bool Function(String path)? pathExists,
  bool Function(String path)? isExecutable,
}) {
  final exists = pathExists ?? _entityExists;
  final executable = isExecutable ?? isExecutableFile;
  final variables = environment ?? Platform.environment;
  final saved = context ?? const ResumeContext();
  // A tile that has never been captured keeps the compositor cwd (the
  // historical launch behaviour) instead of jumping to home; home is the
  // fallback for a *saved* directory that disappeared.
  final workingDirectory = context == null
      ? null
      : _resolveWorkingDirectory(saved.workingDirectory, homeDirectory, exists);
  final resolved = saved.copyWith(workingDirectory: workingDirectory);

  if (customExec != null && customExec.trim().isNotEmpty) {
    var command = customExec;
    final customTokens = DesktopExec.parse(customExec).tokens;
    final emulator = terminalEmulatorFor(
      executable: saved.executable,
      execTemplate: customExec,
      appId: appId,
      capturedArgv: saved.argv,
    );
    if (emulator != null && !emulator.hasCommandArguments(customTokens)) {
      final suffix = _terminalProgramArguments(
        saved: saved,
        emulator: emulator,
        workingDirectory: workingDirectory,
        environment: variables,
        isExecutable: executable,
        // `wezterm` needs its `start` subcommand unless the custom exec
        // already has it; every other terminal's suffix is the whole syntax.
        includeSubcommand:
            emulator.name == 'wezterm' && !customTokens.contains('start'),
      );
      if (suffix != null) {
        command = appendShellArguments(command, suffix);
      }
    }
    return ResumeLaunchPlan(
      config: LaunchConfig(
        command: command,
        workingDirectory: workingDirectory,
      ),
      context: resolved,
    );
  }

  // A terminal's own argv describes the emulator (its flags and server mode),
  // not work to replay. The terminal context supplies the cwd; the desktop
  // entry supplies the command. Keep the captured argv only for the fallback
  // when the entry is gone.
  final arguments = saved.terminal != null ? const <String>[] : saved.arguments;
  final classified = _classifyArguments(arguments, workingDirectory, exists);
  final documents = classified
      .whereType<_ClassifiedArgument>()
      .where((argument) => argument.isDocument && argument.exists)
      .map((argument) => argument.value)
      .toList();
  final nonDocuments = classified
      .whereType<_ClassifiedArgument>()
      .where((argument) => !argument.isDocument)
      .map((argument) => argument.value)
      .toList();

  if (execTemplate != null && execTemplate.trim().isNotEmpty) {
    final exec = DesktopExec.parse(execTemplate);
    final argv = _expandExec(
      exec,
      documents: documents,
      nonDocumentArguments: nonDocuments,
      preservedArguments: classified
          .whereType<_ClassifiedArgument>()
          .where((argument) => !argument.isDocument || argument.exists)
          .map((argument) => argument.value)
          .toList(),
      entryName: entryName,
      entryIcon: entryIcon,
    );
    if (argv.isNotEmpty) {
      final emulator = terminalEmulatorFor(
        executable: saved.executable,
        execTemplate: execTemplate,
        appId: appId,
        capturedArgv: saved.argv,
      );
      if (emulator != null) {
        if (!emulator.hasCommandArguments(exec.tokens)) {
          final suffix = _terminalProgramArguments(
            saved: saved,
            emulator: emulator,
            workingDirectory: workingDirectory,
            environment: variables,
            isExecutable: executable,
            includeSubcommand: true,
          );
          if (suffix != null) {
            argv.addAll(suffix);
          }
        }
      } else if (saved.terminal?.foreground != null) {
        matchingLog.info(
          'Unknown terminal for tile; resuming its shell without replaying '
          '"${saved.terminal!.foreground!.program}"',
        );
      }
      return ResumeLaunchPlan(
        config: LaunchConfig(argv: argv, workingDirectory: workingDirectory),
        context: resolved,
      );
    }
  }

  // No desktop entry (or an unusable one): fall back to the captured command.
  final fallback = _fallbackArgv(
    saved: saved,
    workingDirectory: workingDirectory,
    exists: exists,
  );
  if (fallback.isEmpty) {
    return null;
  }
  return ResumeLaunchPlan(
    config: LaunchConfig(argv: fallback, workingDirectory: workingDirectory),
    context: resolved,
  );
}

String? _resolveWorkingDirectory(
  String? saved,
  String? homeDirectory,
  bool Function(String path) exists,
) {
  if (saved != null && saved.isNotEmpty) {
    if (exists(saved)) {
      return saved;
    }
    matchingLog.info('Saved working directory "$saved" is gone');
  }
  if (homeDirectory != null &&
      homeDirectory.isNotEmpty &&
      exists(homeDirectory)) {
    return homeDirectory;
  }
  return null;
}

/// A saved argument and whether it looks like a document.
class _ClassifiedArgument {
  const _ClassifiedArgument(
    this.value, {
    required this.isDocument,
    required this.exists,
  });

  final String value;
  final bool isDocument;
  final bool exists;
}

List<_ClassifiedArgument> _classifyArguments(
  List<String> arguments,
  String? workingDirectory,
  bool Function(String path) exists,
) {
  return arguments.map((argument) {
    final isDocument = _looksLikeDocument(argument, workingDirectory, exists);
    if (!isDocument) {
      return _ClassifiedArgument(argument, isDocument: false, exists: true);
    }
    final valid = _documentExists(argument, workingDirectory, exists);
    if (!valid) {
      matchingLog.info('Saved document "$argument" is gone; skipping it');
    }
    return _ClassifiedArgument(argument, isDocument: true, exists: valid);
  }).toList();
}

bool _looksLikeDocument(
  String argument,
  String? workingDirectory,
  bool Function(String path) exists,
) {
  if (argument.isEmpty || argument.startsWith('-')) {
    return false;
  }
  final uri = Uri.tryParse(argument);
  if (uri != null && uri.hasScheme) {
    return true;
  }
  if (path.isAbsolute(argument) || argument.contains('/')) {
    return true;
  }
  if (path.extension(argument).isNotEmpty) {
    return true;
  }
  if (workingDirectory != null &&
      exists(path.join(workingDirectory, argument))) {
    return true;
  }
  return false;
}

bool _documentExists(
  String argument,
  String? workingDirectory,
  bool Function(String path) exists,
) {
  final uri = Uri.tryParse(argument);
  if (uri != null && uri.hasScheme) {
    if (uri.scheme != 'file') {
      // Remote URIs (http(s), ...) cannot be validated locally and are kept.
      return true;
    }
    return exists(uri.toFilePath());
  }
  final resolved = path.isAbsolute(argument)
      ? argument
      : workingDirectory == null
      ? argument
      : path.join(workingDirectory, argument);
  return exists(resolved);
}

List<String> _expandExec(
  DesktopExec exec, {
  required List<String> documents,
  required List<String> nonDocumentArguments,
  required List<String> preservedArguments,
  String? entryName,
  String? entryIcon,
}) {
  final argv = <String>[];
  for (final token in exec.tokens) {
    switch (token) {
      case '%f':
        if (documents.isNotEmpty) {
          argv.add(_asFileArgument(documents.first));
        }
      case '%u':
        if (documents.isNotEmpty) {
          argv.add(_asUriArgument(documents.first));
        }
      case '%F':
        argv.addAll(documents.map(_asFileArgument));
      case '%U':
        argv.addAll(documents.map(_asUriArgument));
      case '%i':
        if (entryIcon != null && entryIcon.isNotEmpty) {
          argv
            ..add('--icon')
            ..add(entryIcon);
        }
      case '%c':
        if (entryName != null && entryName.isNotEmpty) {
          argv.add(entryName);
        }
      case '%k' || '%d' || '%D' || '%n' || '%N' || '%v' || '%m':
        // Deprecated/unsupported field codes carry no resume value.
        break;
      case '%%':
        argv.add('%');
      default:
        if (token.length == 2 && token.startsWith('%')) {
          // Unknown field code: dropping it is safer than launching the app
          // with a literal `%x` argument.
          break;
        }
        argv.add(token.replaceAll('%%', '%'));
    }
  }
  argv.addAll(
    exec.hasFileFieldCode ? nonDocumentArguments : preservedArguments,
  );
  return argv;
}

List<String> _fallbackArgv({
  required ResumeContext saved,
  required String? workingDirectory,
  required bool Function(String path) exists,
}) {
  if (saved.argv.isNotEmpty) {
    final command = saved.argv.first;
    final classified = _classifyArguments(
      saved.argv.skip(1).toList(),
      workingDirectory,
      exists,
    );
    return [
      command,
      for (final argument in classified)
        if (!argument.isDocument || argument.exists) argument.value,
    ];
  }
  final executable = saved.executable;
  if (executable == null || executable.isEmpty) {
    return const [];
  }
  final classified = _classifyArguments(
    saved.arguments,
    workingDirectory,
    exists,
  );
  return [
    executable,
    for (final argument in classified)
      if (!argument.isDocument || argument.exists) argument.value,
  ];
}

/// Arguments appended to the terminal command to replay the saved foreground
/// program, or null when nothing safe can be replayed.
List<String>? _terminalProgramArguments({
  required ResumeContext saved,
  required TerminalEmulator emulator,
  required String? workingDirectory,
  required Map<String, String> environment,
  required bool Function(String path) isExecutable,
  required bool includeSubcommand,
}) {
  final terminal = saved.terminal;
  final foreground = terminal?.foreground;
  if (terminal == null || foreground == null) {
    return null;
  }
  if (!isSafeTerminalProgram(foreground.program)) {
    matchingLog.info(
      'Not replaying "${foreground.program}": not on the terminal allowlist',
    );
    return null;
  }
  final program = resolveExecutablePath(
    foreground.program,
    workingDirectory: workingDirectory,
    environment: environment,
    isExecutable: isExecutable,
  );
  if (program == null) {
    matchingLog.warning(
      'Saved terminal program "${foreground.program}" is gone; '
      'resuming the shell only',
    );
    return null;
  }

  final shell = _resolveTerminalShell(
    terminal.shell,
    environment,
    isExecutable,
  );
  if (shell == null) {
    matchingLog.warning(
      'No usable shell to keep alive after "${foreground.program}"; '
      'resuming the shell only',
    );
    return null;
  }

  return [
    ...includeSubcommand
        ? emulator.commandArguments(workingDirectory)
        : emulator.suffixArguments(workingDirectory),
    ..._shellSurvivalCommand(shell, program, foreground.arguments),
  ];
}

String? _resolveTerminalShell(
  String? saved,
  Map<String, String> environment,
  bool Function(String path) isExecutable,
) {
  for (final candidate in [saved, environment['SHELL'], '/bin/sh']) {
    if (candidate == null || candidate.isEmpty) {
      continue;
    }
    if (!isTerminalShell(candidate)) {
      continue;
    }
    final resolved = resolveExecutablePath(
      candidate,
      environment: environment,
      isExecutable: isExecutable,
    );
    if (resolved != null) {
      return resolved;
    }
  }
  return null;
}

/// Runs [program] and then replaces the wrapper with the interactive shell, so
/// the terminal remains at a prompt when the program exits.
List<String> _shellSurvivalCommand(
  String shell,
  String program,
  List<String> arguments,
) => ['/bin/sh', '-c', r'"$@"; exec "$0"', shell, program, ...arguments];

String _asFileArgument(String document) {
  final uri = Uri.tryParse(document);
  return uri != null && uri.scheme == 'file' ? uri.toFilePath() : document;
}

String _asUriArgument(String document) {
  if (path.isAbsolute(document)) {
    return Uri.file(document).toString();
  }
  return document;
}

bool _entityExists(String target) =>
    FileSystemEntity.typeSync(target) != FileSystemEntityType.notFound;
