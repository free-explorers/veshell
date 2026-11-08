import 'dart:io';
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_preview_path.dart';

part 'window_preview_image.g.dart';

/// Directory of the tiles' previews (see [resolveWindowPreviewDirectory]);
/// overridden by tests.
@Riverpod(keepAlive: true)
Directory windowPreviewDirectory(Ref ref) => resolveWindowPreviewDirectory();

/// A stored preview and the place its window occupied in the tile.
class WindowPreview {
  const WindowPreview({required this.image, required this.layout});

  final Image image;

  /// `null` for a preview written before the layout was persisted; the
  /// placeholder then falls back to filling the tile.
  final WindowPreviewLayout? layout;
}

/// The last frame of [windowId]'s window.
///
/// The compositor persists the frame when the window goes away (see the
/// `window_preview` platform request), already averaged down and blurred to
/// the shell's frost: the file never holds a readable window, and the
/// placeholder paints it as is. The tile invalidates this after each close.
/// Returns `null` when the tile has never shown a window.
@riverpod
Future<WindowPreview?> windowPreviewImage(
  Ref ref,
  PersistentWindowId windowId,
) async {
  final directory = ref.watch(windowPreviewDirectoryProvider);
  final file = File(windowPreviewPath(windowId, directory));
  if (!await file.exists()) {
    return null;
  }

  final Image image;
  try {
    final codec = await instantiateImageCodec(await file.readAsBytes());
    image = (await codec.getNextFrame()).image;
  } on Object {
    // A torn or stale file is not worth failing the placeholder over; the
    // icon remains as the fallback.
    return null;
  }
  if (!ref.mounted) {
    image.dispose();
    return null;
  }
  ref.onDispose(image.dispose);
  return WindowPreview(
    image: image,
    layout: readWindowPreviewLayout(windowId, directory),
  );
}
