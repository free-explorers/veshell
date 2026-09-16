import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'screen_cast_active.serializable.freezed.dart';
part 'screen_cast_active.serializable.g.dart';

/// Model for ScreenCastActiveMessage
@freezed
sealed class ScreenCastActiveMessage
    with _$ScreenCastActiveMessage
    implements PlatformMessage {
  /// Factory
  factory ScreenCastActiveMessage({
    required String sessionHandle,
    required String sourceLabel,
  }) = _ScreenCastActiveMessage;

  factory ScreenCastActiveMessage.fromJson(Map<String, dynamic> json) =>
      _$ScreenCastActiveMessageFromJson(json);
}
