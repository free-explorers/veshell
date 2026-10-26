import 'package:collection/collection.dart';
import 'package:shell/platform/model/event/process_info/process_info.serializable.dart';
import 'package:shell/window/model/resume_context.serializable.dart';

/// Builds a resume context from a `/proc` snapshot.
///
/// The terminal's shell cwd wins over the terminal window process's own cwd:
/// the emulator process usually stays wherever it was started, while the shell
/// is where the user actually worked.
ResumeContext? captureResumeContextFromProcessInfo(
  ProcessInfoMessage? info, {
  DateTime? capturedAt,
}) {
  if (info == null) {
    return null;
  }

  final shell = info.terminal?.shell;
  final argv = info.cmdline;
  final executable = info.exe ?? argv.firstOrNull;
  final workingDirectory = shell?.cwd ?? info.cwd;

  if (workingDirectory == null && argv.isEmpty && executable == null) {
    return null;
  }

  return ResumeContext(
    workingDirectory: workingDirectory,
    argv: argv,
    executable: executable,
    cgroup: info.cgroup,
    terminal: shell == null
        ? null
        : TerminalResumeContext(
            shell: shell.exe ?? shell.cmdline.firstOrNull,
            workingDirectory: shell.cwd,
          ),
    capturedAt: capturedAt ?? DateTime.now(),
  );
}

/// Whether two tiles belong to the same application group for a resume burst.
///
/// Same desktop-entry id is the normal grouping. A shared saved cgroup catches
/// windows that belong to the same application instance even when helper
/// surfaces report a different app id.
bool sameResumeGroup({
  required String appIdA,
  String? cgroupA,
  required String appIdB,
  String? cgroupB,
}) {
  if (appIdA.isNotEmpty && appIdA == appIdB) {
    return true;
  }
  return cgroupA != null && cgroupA.isNotEmpty && cgroupA == cgroupB;
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
