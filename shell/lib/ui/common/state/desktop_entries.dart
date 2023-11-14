import 'dart:io';

import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:jovial_svg/jovial_svg.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part '../../../generated/ui/common/state/desktop_entries.g.dart';

@Riverpod(keepAlive: true)
Future<Map<String, DesktopEntry>> installedDesktopEntries(InstalledDesktopEntriesRef ref) async {
  return parseAllInstalledDesktopFiles();
}

@Riverpod(keepAlive: true)
Future<Map<String, LocalizedDesktopEntry>> localizedDesktopEntries(LocalizedDesktopEntriesRef ref) async {
  final desktopEntries = await ref.watch(installedDesktopEntriesProvider.future);
  return desktopEntries.map((key, value) => MapEntry(key, value.localize(lang: 'en')));
}

@Riverpod(keepAlive: true)
Future<Iterable<LocalizedDesktopEntry>> appDrawerDesktopEntries(AppDrawerDesktopEntriesRef ref) async {
  final localizedDesktopEntries = await ref.watch(localizedDesktopEntriesProvider.future);
  return localizedDesktopEntries.values.where((element) => !element.desktopEntry.isHidden());
}

@Riverpod(keepAlive: true)
Future<FreedesktopIconThemes> iconThemes(IconThemesRef ref) async {
  final themes = FreedesktopIconThemes();
  await themes.loadThemes();
  return themes;
}

@Riverpod(keepAlive: true)
Future<File?> icon(IconRef ref, IconQuery query) async {
  final themes = await ref.watch(iconThemesProvider.future);
  return themes.findIcon(query);
}

@Riverpod(keepAlive: true)
Future<ScalableImage> fileToScalableImage(FileToScalableImageRef ref, String path) async {
  String svg = await File(path).readAsString();
  return ScalableImage.fromSvgString(svg);
}
