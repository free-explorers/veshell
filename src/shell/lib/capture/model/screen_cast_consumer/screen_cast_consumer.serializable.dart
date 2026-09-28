import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'screen_cast_consumer.serializable.freezed.dart';
part 'screen_cast_consumer.serializable.g.dart';

/// Model for ScreenCastConsumerMessage
@freezed
sealed class ScreenCastConsumerMessage
    with _$ScreenCastConsumerMessage
    implements PlatformMessage {
  /// Factory
  factory ScreenCastConsumerMessage({
    required String sessionHandle,
    required int pid,
  }) = _ScreenCastConsumerMessage;

  factory ScreenCastConsumerMessage.fromJson(Map<String, dynamic> json) =>
      _$ScreenCastConsumerMessageFromJson(json);
}
