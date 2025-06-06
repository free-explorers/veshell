import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'gesture_swipe_end.serializable.freezed.dart';
part 'gesture_swipe_end.serializable.g.dart';

/// Model for GestureSwipeEndMessage
@freezed
abstract class GestureSwipeEndMessage
    with _$GestureSwipeEndMessage
    implements PlatformMessage {
  /// Factory
  factory GestureSwipeEndMessage({
    required DateTime time,
    required int fingers,
    required bool cancelled,
  }) = _GestureSwipeEndMessage;

  factory GestureSwipeEndMessage.fromJson(Map<String, dynamic> json) =>
      _$GestureSwipeEndMessageFromJson(json);
}
