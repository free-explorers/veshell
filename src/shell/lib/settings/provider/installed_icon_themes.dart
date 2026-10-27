import 'dart:io';
import 'dart:isolate';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/util/icon_theme_preview.dart';
import 'package:shell/settings/provider/util/theme_detection.dart';

part 'installed_icon_themes.g.dart';

/// The icon themes present in the standard XDG locations, sorted for a picker.
///
/// This is the catalogue the settings UI offers; the built-in letter theme is
/// added by the editor rather than reported here, because it is not an
/// installed directory. The provider is auto-disposed so reopening the editor
/// picks up themes installed during the session.
@riverpod
List<String> installedIconThemeNames(Ref ref) {
  final themes = installedIconThemes().toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return themes;
}

/// The icon shown next to [theme] in the picker, so themes can be compared at
/// a glance. Resolved in an isolate: the picker asks for every theme at once.
@riverpod
Future<File?> iconThemePreview(Ref ref, String theme) =>
    Isolate.run(() => findIconThemePreview(theme));
