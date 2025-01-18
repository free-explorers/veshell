import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/util/json_converter/color.dart';

part 'theme_settings.serializable.freezed.dart';
part 'theme_settings.serializable.g.dart';

@freezed
class ThemeSettings with _$ThemeSettings {
  const factory ThemeSettings({
    @ColorConverter() required Color color,
    required String gtkTheme,
    required String iconTheme,
  }) = _ThemeSettings;

  factory ThemeSettings.fromJson(Map<String, dynamic> json) =>
      _$ThemeSettingsFromJson(json);
}
