import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'brightness_changed.serializable.freezed.dart';
part 'brightness_changed.serializable.g.dart';

/// What changed the display brightness.
enum BrightnessChangeSource {
  /// The hardware function keys (owned and swallowed by the compositor, see
  /// `src/embedder/keyboard/`) or the shell's own `adjust_brightness`
  /// request: the shell shows the brightness OSD.
  keys,

  /// The Helm's slider (`set_brightness`), which shows the level itself.
  helm,

  /// The current level, sent when the shell starts.
  sync,
}

/// The compositor changed the display brightness, or reports it.
///
/// `fraction` is the level the compositor settled on, in `0.0..1.0`, so the
/// shell shows the value the hardware actually received. [available] is false
/// when the compositor drives no backlight (external monitors only, or a
/// nested session); only the startup [BrightnessChangeSource.sync] says so.
@freezed
sealed class BrightnessChangedMessage
    with _$BrightnessChangedMessage
    implements PlatformMessage {
  /// Factory
  factory BrightnessChangedMessage({
    required double fraction,
    @Default(true) bool available,
    @JsonKey(unknownEnumValue: BrightnessChangeSource.keys)
    @Default(BrightnessChangeSource.keys)
    BrightnessChangeSource source,
  }) = _BrightnessChangedMessage;

  factory BrightnessChangedMessage.fromJson(Map<String, dynamic> json) =>
      _$BrightnessChangedMessageFromJson(json);
}
