import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/state/icon_theme_setting.dart';
import 'package:shell/settings/provider/util/theme_detection.dart';

part 'icon_themes.g.dart';

@Riverpod(keepAlive: true)
Future<FreedesktopIconTheme> iconThemes(Ref ref) async {
  final preferredTheme = ref.watch(iconThemeSettingProvider);
  final installedThemes = await FreedesktopIconTheme.installedThemes;
  final theme = chooseIconTheme(
    installedThemes,
    configured: preferredTheme,
    systemTheme: systemIconTheme(),
  );
  return await FreedesktopIconTheme.loadTheme(theme: theme);
}
