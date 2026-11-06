import 'dart:isolate';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/util/cursor_theme_preview.dart';
import 'package:shell/settings/provider/util/theme_detection.dart';

part 'installed_cursor_themes.g.dart';

/// The Xcursor themes present in the standard XDG locations, sorted for a
/// picker. Auto-disposed so reopening the editor picks up new themes.
@riverpod
List<String> installedCursorThemeNames(Ref ref) =>
    installedCursorThemes().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

/// The arrow of [theme], shown next to it in the picker. Parsed in an isolate:
/// the picker asks for every theme at once.
@riverpod
Future<CursorImage?> cursorThemePreview(Ref ref, String theme) =>
    Isolate.run(() => findCursorThemePreview(theme));
