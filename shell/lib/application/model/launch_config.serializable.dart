import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'launch_config.serializable.freezed.dart';
part 'launch_config.serializable.g.dart';

@freezed
abstract class LaunchConfig with _$LaunchConfig {
  const factory LaunchConfig({
    required String command,
    @Default([]) List<String> arguments,
    @Default(false) bool useDedicatedGpu,
  }) = _LaunchConfig;

  factory LaunchConfig.fromJson(Map<String, dynamic> json) =>
      _$LaunchConfigFromJson(json);

  factory LaunchConfig.fromDesktopEntry(DesktopEntry desktopEntry) {
    var command =
        desktopEntry.entries[DesktopEntryKey.exec.string]?.value ?? '';
    command = command.replaceAll(RegExp('( %.?)'), '');
    return LaunchConfig(
      command: command,
      arguments: [],
    );
  }
}
