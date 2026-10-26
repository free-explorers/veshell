import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'process_info.serializable.freezed.dart';
part 'process_info.serializable.g.dart';

/// Process-level facts read from `/proc` for a surface client pid.
///
/// Delivered keyed by pid rather than duplicated on every window: the cgroup
/// and the raw Flatpak/Snap/binary identities belong to the process. Snapshot
/// at window creation, refreshed when the pid changes, when the window is
/// mapped, when its title changes, and on demand while a tile is displayed.
@freezed
abstract class ProcessInfoMessage
    with _$ProcessInfoMessage
    implements PlatformMessage {
  /// Factory
  factory ProcessInfoMessage({
    required int pid,
    String? cgroup,
    String? flatpakId,
    String? snapId,
    String? binaryName,
    @Default(<String>[]) List<String> cmdline,
    String? cwd,
    String? exe,
    TerminalInfoMessage? terminal,
  }) = _ProcessInfoMessage;

  factory ProcessInfoMessage.fromJson(Map<String, dynamic> json) =>
      _$ProcessInfoMessageFromJson(json);
}

/// Terminal-specific process context.
@freezed
abstract class TerminalInfoMessage with _$TerminalInfoMessage {
  factory TerminalInfoMessage({
    ProcessDescriptorMessage? shell,
    ProcessDescriptorMessage? foreground,
  }) = _TerminalInfoMessage;

  factory TerminalInfoMessage.fromJson(Map<String, dynamic> json) =>
      _$TerminalInfoMessageFromJson(json);
}

/// One process in a terminal's shell/foreground chain.
@freezed
abstract class ProcessDescriptorMessage with _$ProcessDescriptorMessage {
  factory ProcessDescriptorMessage({
    required int pid,
    @Default(<String>[]) List<String> cmdline,
    String? exe,
    String? cwd,
  }) = _ProcessDescriptorMessage;

  factory ProcessDescriptorMessage.fromJson(Map<String, dynamic> json) =>
      _$ProcessDescriptorMessageFromJson(json);
}
