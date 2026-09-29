import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'screen_cast_recording.serializable.freezed.dart';
part 'screen_cast_recording.serializable.g.dart';

/// Model for ScreenCastRecordingMessage
///
/// Where a live screen cast was placed: the MetaWindow id it resolved to, or
/// `null` for an orphan cast no window can display (the persistent bar's
/// fallback case).
@freezed
sealed class ScreenCastRecordingMessage
    with _$ScreenCastRecordingMessage
    implements PlatformMessage {
  /// Factory
  factory ScreenCastRecordingMessage({
    required String sessionHandle,
    required String? metaWindowId,
  }) = _ScreenCastRecordingMessage;

  factory ScreenCastRecordingMessage.fromJson(Map<String, dynamic> json) =>
      _$ScreenCastRecordingMessageFromJson(json);
}
