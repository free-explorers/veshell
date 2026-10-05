import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'brightness_changed.serializable.freezed.dart';
part 'brightness_changed.serializable.g.dart';

/// The compositor changed the display brightness.
///
/// Emitted after every user-driven brightness step — the hardware function keys
/// (owned and swallowed by the compositor, see `src/embedder/keyboard/`) and the
/// shell's own `adjust_brightness` request. `fraction` is the level the
/// compositor settled on, in `0.0..1.0`, so the shell can show the brightness
/// OSD with the value the hardware actually received.
@freezed
sealed class BrightnessChangedMessage
    with _$BrightnessChangedMessage
    implements PlatformMessage {
  /// Factory
  factory BrightnessChangedMessage({required double fraction}) =
      _BrightnessChangedMessage;

  factory BrightnessChangedMessage.fromJson(Map<String, dynamic> json) =>
      _$BrightnessChangedMessageFromJson(json);
}
