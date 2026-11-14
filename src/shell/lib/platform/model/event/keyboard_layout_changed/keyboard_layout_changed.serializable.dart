import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'keyboard_layout_changed.serializable.freezed.dart';
part 'keyboard_layout_changed.serializable.g.dart';

/// The seat's active keyboard layout, sent by the compositor whenever it may
/// have changed: after a layout switch, after the keymap is recompiled from
/// the settings, and when the shell (re)starts.
///
/// [index] is the layout's position in `keyboard.layout`, [count] how many
/// layouts the keymap has, and [name] the layout's xkb name
/// (`English (US)`).
@freezed
sealed class KeyboardLayoutChangedMessage
    with _$KeyboardLayoutChangedMessage
    implements PlatformMessage {
  /// Factory
  factory KeyboardLayoutChangedMessage({
    required int index,
    required int count,
    required String name,
  }) = _KeyboardLayoutChangedMessage;

  factory KeyboardLayoutChangedMessage.fromJson(Map<String, dynamic> json) =>
      _$KeyboardLayoutChangedMessageFromJson(json);
}
