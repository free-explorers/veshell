import 'package:freezed_annotation/freezed_annotation.dart';

part 'resume_context.serializable.freezed.dart';
part 'resume_context.serializable.g.dart';

/// The saved launch context of a persistent tile.
///
/// This is deliberately separate from the tile's `properties`: properties
/// describe the native window currently displayed and are overwritten whenever
/// another window takes the tile, while the resume context is the tile's own
/// durable memory of how to start that work again.
@freezed
abstract class ResumeContext with _$ResumeContext {
  const factory ResumeContext({
    /// Directory the application was running in.
    String? workingDirectory,

    /// Captured command line, including argv[0].
    ///
    /// Used as the fallback launch command when the desktop entry is gone, and
    /// as the source of arguments/documents when it still exists.
    @Default(<String>[]) List<String> argv,

    /// Resolved executable (`/proc/<pid>/exe`) or argv[0].
    String? executable,

    /// Terminal-only context: the shell and its working directory.
    TerminalResumeContext? terminal,

    /// When the context was last refreshed.
    DateTime? capturedAt,
  }) = _ResumeContext;

  const ResumeContext._();

  /// Arguments passed to [executable], i.e. [argv] without its first element.
  List<String> get arguments => argv.length <= 1 ? const [] : argv.sublist(1);

  factory ResumeContext.fromJson(Map<String, dynamic> json) =>
      _$ResumeContextFromJson(json);
}

/// Terminal-specific resume context.
@freezed
abstract class TerminalResumeContext with _$TerminalResumeContext {
  const factory TerminalResumeContext({
    /// Path to the interactive shell process.
    String? shell,

    /// The shell's current directory, which may differ from the terminal
    /// window process's own cwd.
    String? workingDirectory,

    /// Foreground job, present only when it was verified and safe to replay.
    ///
    /// The terminal policy (#188) owns the allowlist and replay syntax.
    ForegroundProgram? foreground,
  }) = _TerminalResumeContext;

  factory TerminalResumeContext.fromJson(Map<String, dynamic> json) =>
      _$TerminalResumeContextFromJson(json);
}

/// A terminal foreground program captured for a possible replay.
@freezed
abstract class ForegroundProgram with _$ForegroundProgram {
  const factory ForegroundProgram({
    required String program,
    @Default(<String>[]) List<String> arguments,
  }) = _ForegroundProgram;

  factory ForegroundProgram.fromJson(Map<String, dynamic> json) =>
      _$ForegroundProgramFromJson(json);
}
