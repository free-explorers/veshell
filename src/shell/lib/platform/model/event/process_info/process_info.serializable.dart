import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'process_info.serializable.freezed.dart';
part 'process_info.serializable.g.dart';

/// Process-level facts read from `/proc` for a surface client pid.
///
/// Delivered keyed by pid rather than duplicated on every window: the cgroup
/// and the raw Flatpak/Snap/binary identities belong to the process. Snapshot
/// at window creation, refreshed when the pid changes and when the window is
/// mapped.
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
  }) = _ProcessInfoMessage;

  factory ProcessInfoMessage.fromJson(Map<String, dynamic> json) =>
      _$ProcessInfoMessageFromJson(json);
}
