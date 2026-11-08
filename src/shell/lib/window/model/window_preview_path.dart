import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as path;
import 'package:shell/shared/util/file.dart';
import 'package:shell/window/model/window_id.serializable.dart';

/// Directory of the tiles' last-frame previews: `window_previews/` in the
/// compositor's cache directory (`VESHELL_CACHE_DIR`), which the compositor
/// writes and sweeps of removed tiles at startup.
Directory resolveWindowPreviewDirectory() {
  final cacheDirectory = Platform.environment['VESHELL_CACHE_DIR'];
  if (cacheDirectory == null || cacheDirectory.isEmpty) {
    throw StateError(
      'VESHELL_CACHE_DIR is not set: cannot locate the window previews',
    );
  }
  return Directory(path.join(cacheDirectory, 'window_previews'));
}

/// The persisted preview of [windowId].
///
/// The compositor writes the file (see the `window_preview` platform request),
/// already frosted; the shell only reads it and removes it with the tile.
String windowPreviewPath(PersistentWindowId windowId, Directory directory) =>
    path.join(directory.path, '${windowId.uuid}.png');

/// Where the preview sat in its tile, for the placeholder to draw it at the
/// window's own size instead of stretching it over the whole tile.
String windowPreviewLayoutPath(
  PersistentWindowId windowId,
  Directory directory,
) => path.join(directory.path, '${windowId.uuid}.layout');

/// The displayed size of the last window and whether it filled its tile.
class WindowPreviewLayout {
  const WindowPreviewLayout({required this.size, required this.fullBleed});

  final Size size;

  /// The window covered its tile (a maximized/fullscreen surface): the preview
  /// fills whatever tile the placeholder currently occupies.
  final bool fullBleed;
}

/// Reads the layout persisted for [windowId], if any.
WindowPreviewLayout? readWindowPreviewLayout(
  PersistentWindowId windowId,
  Directory directory,
) {
  final file = File(windowPreviewLayoutPath(windowId, directory));
  if (!file.existsSync()) {
    return null;
  }
  try {
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final width = (data['width'] as num?)?.toDouble();
    final height = (data['height'] as num?)?.toDouble();
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return WindowPreviewLayout(
      size: Size(width, height),
      fullBleed: data['fullBleed'] == true,
    );
  } on Object {
    // A torn file is only a layout hint; the preview still works without it.
    return null;
  }
}

/// Persists the layout ([size], [fullBleed]) with the preview.
Future<void> writeWindowPreviewLayout(
  PersistentWindowId windowId,
  Directory directory, {
  required Size size,
  required bool fullBleed,
}) => writeFileAtomicallyNow(
  windowPreviewLayoutPath(windowId, directory),
  jsonEncode({
    'width': size.width,
    'height': size.height,
    'fullBleed': fullBleed,
  }),
);
