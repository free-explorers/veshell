import 'package:flutter/material.dart';

const veshellColor = Color.fromARGB(255, 67, 76, 94);
const surfaceRadius = 24.0;
const panelSize = 48.0;

class VeshellTheme {
  static ThemeData get light => _buildTheme(
        ThemeData.light(
          useMaterial3: true,
        ),
      );
  static ThemeData get dark => _buildTheme(
        ThemeData.dark(
          useMaterial3: true,
        ),
      );

  static ThemeData _buildTheme(ThemeData defaultTheme) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: veshellColor,
      brightness: defaultTheme.brightness,
    );

    final lighterSurface = Color.lerp(
      colorScheme.surface,
      Colors.white,
      0.4,
    )!;

    var theme = defaultTheme.copyWith(
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      highlightColor: lighterSurface.withOpacity(0.12),
      focusColor: lighterSurface.withOpacity(0.24),
      hoverColor: lighterSurface.withOpacity(0.08),
    );

    theme = _applyCardTheme(theme);
    return theme;
  }

  static ThemeData _applyCardTheme(ThemeData theme) {
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
