import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'screen_cast_stop.serializable.freezed.dart';
part 'screen_cast_stop.serializable.g.dart';

/// Model for [ScreenCastStopMessage]
///
/// The persistent indicator's trusted Stop action.
@freezed
sealed class ScreenCastStopMessage
    with _$ScreenCastStopMessage
    implements PlatformMessage {
  /// Factory
  factory ScreenCastStopMessage({
    required String sessionHandle,
  }) = _ScreenCastStopMessage;

  factory ScreenCastStopMessage.fromJson(Map<String, dynamic> json) =>
      _$ScreenCastStopMessageFromJson(json);
}
