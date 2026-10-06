import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/settings/provider/state/theme_color_setting.dart';
import 'package:shell/theme/fonts.dart';

part 'theme.g.dart';

const surfaceRadius = 24.0;
const panelSize = 48.0;

@riverpod
class VeshellTheme extends _$VeshellTheme {
  @override
  (ThemeData, ThemeData) build() {
    final color = ref.watch(themeColorSettingProvider);
    final fallbacks = shellFontFallbacks(ref.watch(shellLocaleProvider));

    ThemeData defaults(Brightness brightness) => ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Roboto',
      fontFamilyFallback: fallbacks,
    );

    return (
      _buildTheme(defaults(Brightness.light), color),
      _buildTheme(defaults(Brightness.dark), color),
    );
  }

  ThemeData _buildTheme(ThemeData defaultTheme, Color themeColor) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: themeColor,
      brightness: defaultTheme.brightness,
      // Keep the seed's own chroma: the default `tonalSpot` pastelises the
      // primary, while `fidelity` derives the palettes from the seed color
      // itself so the theme reads as the chosen color.
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

    final lighterSurface = Color.lerp(colorScheme.surface, Colors.white, 0.4)!;

    final theme = defaultTheme.copyWith(
      visualDensity: VisualDensity.standard,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      highlightColor: lighterSurface.withAlpha(30),
      focusColor: lighterSurface.withAlpha(60),
      hoverColor: lighterSurface.withAlpha(20),
      tooltipTheme: defaultTheme.tooltipTheme.copyWith(
        decoration: BoxDecoration(
          color: colorScheme.surface.withAlpha(200),
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: defaultTheme.textTheme.bodyMedium!.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
    );

    return _applyCardTheme(theme);
  }

  ThemeData _applyCardTheme(ThemeData theme) {
    return theme.copyWith(
      cardTheme: theme.cardTheme.copyWith(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(surfaceRadius),
        ),
      ),
    );
  }
}
