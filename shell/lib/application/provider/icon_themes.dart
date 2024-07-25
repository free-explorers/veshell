import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'icon_themes.g.dart';

@Riverpod(keepAlive: true)
Future<FreedesktopIconTheme> iconThemes(IconThemesRef ref) async {
  return FreedesktopIconTheme.loadTheme(theme: 'Adwaita');
}
