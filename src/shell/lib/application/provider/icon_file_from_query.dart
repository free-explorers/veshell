import 'dart:io';

import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/icon_themes.dart';
import 'package:shell/settings/provider/state/icon_theme_setting.dart';
import 'package:shell/settings/provider/util/theme_detection.dart';

part 'icon_file_from_query.g.dart';

/// Resolve the themed icon path without owning a decoded native image.
///
/// Kept alive on purpose. The resolved [File] is tiny — a reference per icon
/// and physical-size bucket — and the queries are bucketed (see
/// `iconPhysicalBucket`), so the family stays bounded by the installed apps.
/// In return, a widget that remounts (a page scrolled out of a `PageView`, a
/// launcher grid rebuilt on search) reads the path synchronously and starts
/// painting immediately instead of waiting on the filesystem lookup. The
/// decoded pixels are cached separately, by Flutter.
@Riverpod(keepAlive: true)
Future<File?> iconFileFromQuery(Ref ref, IconQuery query) async {
  // The letter theme is deliberately not a real icon theme: every icon site
  // falls back to its application-name badge instead of consulting a theme.
  if (isLetterIconTheme(ref.watch(iconThemeSettingProvider))) {
    return null;
  }
  final themes = await ref.watch(iconThemesProvider.future);
  final icon = await themes.findIcon(query);
  // An absolute icon path from a desktop file is returned without checking the
  // filesystem. Treat a vanished file as a missing icon so the letter fallback
  // can take over instead of painting a broken image.
  if (icon != null && !icon.existsSync()) return null;
  return icon;
}
