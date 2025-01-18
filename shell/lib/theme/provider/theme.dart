import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/model/theme_settings.serializable.dart';
import 'package:shell/settings/provider/veshell_settings.dart';

part 'theme.g.dart';

const surfaceRadius = 24.0;
const panelSize = 48.0;

@riverpod
class VeshellTheme extends _$VeshellTheme {
  @override
  (ThemeData, ThemeData) build() {
    final themeSettings = ref.watch(veshellSettingsStateProvider).theme;

    return (
      _buildTheme(
        ThemeData.light(
          useMaterial3: true,
        ),
        themeSettings,
      ),
      _buildTheme(
        ThemeData.dark(
          useMaterial3: true,
        ),
        themeSettings,
      )
    );
  }

  ThemeData _buildTheme(ThemeData defaultTheme, ThemeSettings settings) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: settings.color,
      brightness: defaultTheme.brightness,
    );

    final lighterSurface = Color.lerp(
      colorScheme.surface,
      Colors.white,
      0.4,
    )!;

    final theme = defaultTheme.copyWith(
      visualDensity: VisualDensity.standard,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      highlightColor: lighterSurface.withAlpha(30),
      focusColor: lighterSurface.withAlpha(60),
      hoverColor: lighterSurface.withAlpha(20),
    );

    return _applyCardTheme(theme);
  }

  ThemeData _applyCardTheme(ThemeData theme) {
    return theme.copyWith(
      cardTheme: theme.cardTheme.copyWith(
        color: theme.colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(surfaceRadius),
        ),
      ),
    );
  }
}
