import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/state/icon_theme_setting.dart';

part 'icon_themes.g.dart';

@Riverpod(keepAlive: true)
Future<FreedesktopIconTheme> iconThemes(Ref ref) async {
  final theme = ref.watch(iconThemeSettingProvider);
  return FreedesktopIconTheme.loadTheme(theme: theme);
}
