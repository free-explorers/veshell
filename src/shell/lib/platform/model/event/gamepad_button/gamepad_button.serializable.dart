import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'gamepad_button.serializable.freezed.dart';
part 'gamepad_button.serializable.g.dart';

/// A gamepad control was pressed or released.
///
/// The compositor reads the gamepads itself (libinput ignores them), merges
/// every pad into one logical set and turns the sticks into digital
/// directions, so [button] is one of the names of `GamepadButton`. Nothing is
/// sent while a window is in gaming mode: the game reads the pad itself.
@freezed
sealed class GamepadButtonMessage
    with _$GamepadButtonMessage
    implements PlatformMessage {
  /// Factory
  factory GamepadButtonMessage({
    required String button,
    required bool pressed,
  }) = _GamepadButtonMessage;

  factory GamepadButtonMessage.fromJson(Map<String, dynamic> json) =>
      _$GamepadButtonMessageFromJson(json);
}
