import 'package:freezed_annotation/freezed_annotation.dart';

part 'keyboard_settings.serializable.freezed.dart';
part 'keyboard_settings.serializable.g.dart';

@freezed
class KeyboardSettings with _$KeyboardSettings {
  const factory KeyboardSettings({
    required String layout,
  }) = _KeyboardSettings;

  factory KeyboardSettings.fromJson(Map<String, dynamic> json) =>
      _$KeyboardSettingsFromJson(json);
}
