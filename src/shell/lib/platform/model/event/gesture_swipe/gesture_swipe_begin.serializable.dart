import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'gesture_swipe_begin.serializable.freezed.dart';
part 'gesture_swipe_begin.serializable.g.dart';

/// Model for GestureSwipeBeginMessage
@freezed
abstract class GestureSwipeBeginMessage
    with _$GestureSwipeBeginMessage
    implements PlatformMessage {
  /// Factory
  factory GestureSwipeBeginMessage({
    required DateTime time,
    required int fingers,
  }) = _GestureSwipeBeginMessage;

  factory GestureSwipeBeginMessage.fromJson(Map<String, dynamic> json) =>
      _$GestureSwipeBeginMessageFromJson(json);
}
