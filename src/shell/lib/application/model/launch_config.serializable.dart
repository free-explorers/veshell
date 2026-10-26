import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'launch_config.serializable.freezed.dart';
part 'launch_config.serializable.g.dart';

/// How an application should be started.
///
/// Exactly one of [command] (shell string, used by custom exec) or [argv]
/// (argument vector, used by resume launches) is populated. [argv] is the safe
/// form: paths and documents are never interpolated into a shell command.
@freezed
abstract class LaunchConfig with _$LaunchConfig {
  const factory LaunchConfig({
    String? command,
    @Default(<String>[]) List<String> argv,
    @Default(false) bool useDedicatedGpu,

    /// Directory the application should start in.
    ///
    /// Validated by the caller; the launcher falls back to the compositor's
    /// cwd only when this is null.
    String? workingDirectory,
  }) = _LaunchConfig;

  const LaunchConfig._();

  factory LaunchConfig.fromJson(Map<String, dynamic> json) =>
      _$LaunchConfigFromJson(json);

  /// Fresh launcher path: keep the historical shell-form command.
  ///
  /// Field codes are stripped because the launcher is always fresh and has no
  /// documents to substitute. Resume launches use `desktop_exec.dart` instead.
  factory LaunchConfig.fromDesktopEntry(DesktopEntry desktopEntry) {
    var command =
        desktopEntry.entries[DesktopEntryKey.exec.string]?.value ?? '';
    command = command.replaceAll(RegExp('( %.?)'), '');
    return LaunchConfig(command: command);
  }

  /// Human-readable command for the execution-log viewer.
  String get displayCommand => command ?? (argv.isEmpty ? '' : argv.join(' '));
}
