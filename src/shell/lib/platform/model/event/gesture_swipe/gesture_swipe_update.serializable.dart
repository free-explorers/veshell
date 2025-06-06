import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'gesture_swipe_update.serializable.freezed.dart';
part 'gesture_swipe_update.serializable.g.dart';

/// Model for GestureSwipeUpdateMessage
@freezed
abstract class GestureSwipeUpdateMessage
    with _$GestureSwipeUpdateMessage
    implements PlatformMessage {
  /// Factory
  factory GestureSwipeUpdateMessage({
    required DateTime time,
    required int fingers,
    required double deltaX,
    required double deltaY,
  }) = _GestureSwipeUpdateMessage;

  factory GestureSwipeUpdateMessage.fromJson(Map<String, dynamic> json) =>
      _$GestureSwipeUpdateMessageFromJson(json);
}
