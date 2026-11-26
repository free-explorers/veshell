import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart' as path;
import 'package:shell/application/model/steam_game.dart';

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

    /// Steam app id of a game Steam launched, native or through Proton.
    ///
    /// The game is relaunched through Steam (`steam://rungameid/<id>`): Wine
    /// rewrites a Proton game's argv to its Windows command line
    /// (`Z:\...\Game.exe`), which no Linux launcher can run, and a native
    /// game expects Steam's runtime and client around it.
    String? steamAppId,

    /// How plain Wine (not Proton) ran the program, to run it again.
    WineResumeContext? wine,

    /// When the context was last refreshed.
    DateTime? capturedAt,
  }) = _ResumeContext;

  factory ResumeContext.fromJson(Map<String, dynamic> json) =>
      _$ResumeContextFromJson(json);

  const ResumeContext._();

  /// Arguments passed to [executable], i.e. [argv] without its first element.
  List<String> get arguments => argv.length <= 1 ? const [] : argv.sublist(1);

  /// Whether [argument] names a file of the captured program's own
  /// installation rather than the user's work.
  ///
  /// Wrapper launchers start the real binary with its own resources: Zotero's
  /// `zotero` script runs `zotero-bin -app /usr/lib/zotero/application.ini`,
  /// an interpreter receives its script. Such a path is plumbing, never a
  /// document to reopen: it lives next to the executable or under a system
  /// installation prefix.
  bool isProgramFile(String argument) {
    final uri = Uri.tryParse(argument);
    final String file;
    if (uri != null && uri.hasScheme) {
      if (uri.scheme != 'file') {
        return false;
      }
      file = uri.toFilePath();
    } else {
      file = argument;
    }
    if (!path.isAbsolute(file)) {
      return false;
    }
    final normalized = path.normalize(file);
    for (final program in [executable, argv.firstOrNull]) {
      if (program != null &&
          path.isAbsolute(program) &&
          path.isWithin(path.dirname(program), normalized)) {
        return true;
      }
    }
    return _installationPrefixes.any(
      (prefix) => path.isWithin(prefix, normalized),
    );
  }

  /// The saved command line in a form suitable for display.
  ///
  /// Mirrors the relaunch fallback: the captured [argv] when present,
  /// otherwise the resolved [executable].
  String? get displayCommand {
    final appId = steamAppId;
    if (appId != null) {
      return steamGameUri(appId);
    }
    if (argv.isNotEmpty) {
      return argv.join(' ');
    }
    final program = executable;
    return program == null || program.isEmpty ? null : program;
  }
}

/// Where programs and their resources are installed, as opposed to where
/// users keep documents.
const _installationPrefixes = [
  '/usr',
  '/opt',
  '/bin',
  '/sbin',
  '/lib',
  '/lib64',
  '/app',
  '/snap',
  '/nix/store',
  '/gnu/store',
];

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

/// The Wine configuration a Windows program ran with.
///
/// The program itself is the captured argv (its Windows command line, which
/// Wine resolves through the prefix's drive letters) and the Wine build is the
/// loader the process ran as ([ResumeContext.executable]).
@freezed
abstract class WineResumeContext with _$WineResumeContext {
  const factory WineResumeContext({
    /// Wine configuration variables, `WINEPREFIX` included.
    @Default(<String, String>{}) Map<String, String> environment,
  }) = _WineResumeContext;

  factory WineResumeContext.fromJson(Map<String, dynamic> json) =>
      _$WineResumeContextFromJson(json);
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
