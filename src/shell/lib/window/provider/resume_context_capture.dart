import 'package:collection/collection.dart';
import 'package:shell/application/model/terminal_program_policy.dart';
import 'package:shell/platform/model/event/process_info/process_info.serializable.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/window/model/resume_context.serializable.dart';

/// Builds a resume context from a `/proc` snapshot.
///
/// The terminal's shell cwd wins over the terminal window process's own cwd:
/// the emulator process usually stays wherever it was started, while the shell
/// is where the user actually worked.
ResumeContext? captureResumeContextFromProcessInfo(
  ProcessInfoMessage? info, {
  DateTime? capturedAt,
  Map<String, String>? environment,
  bool Function(String path)? isExecutable,
}) {
  if (info == null) {
    return null;
  }

  final shellDescriptor = info.terminal?.shell;
  final argv = info.cmdline;
  final executable = info.exe ?? argv.firstOrNull;
  final workingDirectory = shellDescriptor?.cwd ?? info.cwd;

  if (workingDirectory == null && argv.isEmpty && executable == null) {
    return null;
  }

  final shell = shellDescriptor == null
      ? null
      : shellDescriptor.exe ?? shellDescriptor.cmdline.firstOrNull;
  final validShell = shell != null && isTerminalShell(shell) ? shell : null;
  final foregroundDescriptor = info.terminal?.foreground;
  final foreground = foregroundDescriptor == null
      ? null
      : _safeForeground(
          foregroundDescriptor,
          workingDirectory,
          environment,
          isExecutable,
        );

  return ResumeContext(
    workingDirectory: workingDirectory,
    argv: argv,
    executable: executable,
    terminal: shellDescriptor == null
        ? null
        : TerminalResumeContext(
            shell: validShell,
            workingDirectory: workingDirectory,
            foreground: foreground,
          ),
    capturedAt: capturedAt ?? DateTime.now(),
  );
}

ForegroundProgram? _safeForeground(
  ProcessDescriptorMessage descriptor,
  String? workingDirectory,
  Map<String, String>? environment,
  bool Function(String path)? isExecutable,
) {
  final program = descriptor.exe ?? descriptor.cmdline.firstOrNull;
  if (program == null || program.isEmpty) {
    return null;
  }
  if (!isSafeTerminalProgram(program)) {
    matchingLog.fine(
      'Not resuming terminal foreground "$program": not allowlisted',
    );
    return null;
  }
  final resolved = resolveExecutablePath(
    program,
    workingDirectory: workingDirectory,
    environment: environment,
    isExecutable: isExecutable,
  );
  if (resolved == null) {
    matchingLog.warning(
      'Allowlisted terminal program "$program" is not executable; '
      'resuming the shell only',
    );
    return null;
  }
  return ForegroundProgram(
    program: resolved,
    arguments: descriptor.cmdline.skip(1).toList(),
  );
}

/// Compares contexts while ignoring the capture timestamp.
///
/// Polling refreshes the timestamp only when the meaningful facts changed, so a
/// terminal sitting idle does not write the persisted state every few seconds.
bool sameResumeContext(ResumeContext? a, ResumeContext? b) {
  if (a == null || b == null) {
    return a == b;
  }
  return a.copyWith(capturedAt: null) == b.copyWith(capturedAt: null);
}
