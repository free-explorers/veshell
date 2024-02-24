import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/desktop_entries.dart';

part 'icon_themes.g.dart';

@Riverpod(keepAlive: true)
Future<FreedesktopIconThemes> iconThemes(IconThemesRef ref) async {
  final themes = FreedesktopIconThemes();
  await themes.loadThemes();
  return themes;
}
