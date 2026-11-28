import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'night_light_changed.serializable.freezed.dart';
part 'night_light_changed.serializable.g.dart';

/// Night Light's state, sent by the compositor whenever it changes (the Helm
/// toggle, the schedule, the settings), when the outputs change and when the
/// shell starts.
///
/// [active] is whether Night Light is on (it may still be fading), and
/// [supported] whether any output can show it: the Helm hides the toggle when
/// none can. See `docs/specifications/night_light.md`.
@freezed
sealed class NightLightChangedMessage
    with _$NightLightChangedMessage
    implements PlatformMessage {
  /// Factory
  factory NightLightChangedMessage({
    required bool active,
    required bool supported,
  }) = _NightLightChangedMessage;

  factory NightLightChangedMessage.fromJson(Map<String, dynamic> json) =>
      _$NightLightChangedMessageFromJson(json);
}
