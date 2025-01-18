import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/settings/model/keyboard_settings.serializable.dart';
import 'package:shell/settings/model/theme_settings.serializable.dart';

part 'veshell_settings.serializable.freezed.dart';
part 'veshell_settings.serializable.g.dart';

@freezed
class VeshellSettings with _$VeshellSettings {
  const factory VeshellSettings({
    required KeyboardSettings keyboard,
    required ThemeSettings theme,
  }) = _VeshellSettings;

  factory VeshellSettings.fromJson(Map<String, dynamic> json) =>
      _$VeshellSettingsFromJson(json);
}
