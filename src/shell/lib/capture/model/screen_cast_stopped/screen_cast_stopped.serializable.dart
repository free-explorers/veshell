import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'screen_cast_stopped.serializable.freezed.dart';
part 'screen_cast_stopped.serializable.g.dart';

/// Model for ScreenCastStoppedMessage
@freezed
sealed class ScreenCastStoppedMessage
    with _$ScreenCastStoppedMessage
    implements PlatformMessage {
  /// Factory
  factory ScreenCastStoppedMessage({
    required String sessionHandle,
  }) = _ScreenCastStoppedMessage;

  factory ScreenCastStoppedMessage.fromJson(Map<String, dynamic> json) =>
      _$ScreenCastStoppedMessageFromJson(json);
}
