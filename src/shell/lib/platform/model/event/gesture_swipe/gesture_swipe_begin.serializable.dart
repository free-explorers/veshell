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
    required int time,
    required int fingers,

    /// Whether the touchpad has natural scrolling on, in which case the
    /// update deltas are negated (content follows the fingers).
    @Default(false) bool naturalScroll,
  }) = _GestureSwipeBeginMessage;

  factory GestureSwipeBeginMessage.fromJson(Map<String, dynamic> json) =>
      _$GestureSwipeBeginMessageFromJson(json);
}
