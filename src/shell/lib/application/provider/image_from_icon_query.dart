import 'dart:ui';

import 'package:flutter_svg/svg.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/icon_themes.dart';

part 'image_from_icon_query.g.dart';

/// Decodes an icon into a native [Image] for one `(query, size)`.
///
/// This provider is auto-dispose: the family key includes the layout size, so
/// a `keepAlive` cache retained one native image per size ever requested while
/// the shell ran. Releasing the image when no icon widget watches it keeps the
/// cache bounded by what is on screen.
@riverpod
class ImageFromIconQuery extends _$ImageFromIconQuery {
  /// The image currently handed to the widget tree.
  ///
  /// The notifier outlives its rebuilds, so this lets a rebuild keep painting
  /// the previous image while the new one decodes instead of disposing it out
  /// from under the widget (which briefly blanked every icon when the icon
  /// theme resolved at session start).
  Image? _image;

  /// Incremented on every build so a superseded decode can detect that a newer
  /// one has taken over and drop its result instead of clobbering it.
  int _buildGeneration = 0;

  @override
  Future<Image?> build(IconQuery query, Size size) async {
    final generation = ++_buildGeneration;

    // `onDispose` also runs before every rebuild, where [_image] is still the
    // provider's value and may be on screen. Only free the native image when
    // the provider is really going away.
    ref.onDispose(() {
      if (ref.mounted) return;
      _image?.dispose();
      _image = null;
    });

    final previous = _image;
    final image = await _decode(query, size);

    // Disposed, or a newer build already started: this result is stale.
    // Freeing it keeps the cache bounded to what is actually on screen.
    if (!ref.mounted || generation != _buildGeneration) {
      image?.dispose();
      return null;
    }
    if (image == null) {
      // Keep [previous] around: the widget may still be painting it, and the
      // disposal callback registered above will free it.
      return null;
    }

    _image = image;
    // The widget painted [previous] for as long as this decode was in flight;
    // the new image replaces it now, so the old handle can be released.
    if (previous != null && !identical(previous, image)) {
      previous.dispose();
    }
    return image;
  }

  Future<Image?> _decode(IconQuery query, Size size) async {
    final themes = await ref.watch(iconThemesProvider.future);
    final file = await themes.findIcon(query);
    if (file == null) return null;
    if (file.path.endsWith('.svg')) {
      final pictureInfo = await vg.loadPicture(SvgFileLoader(file), null);
      final pictureRecorder = PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      // Calculate the scale factor
      final scaleFactor = size.width / pictureInfo.size.width;
      // Apply the scale factor to the canvas
      if (scaleFactor != 0) {
        canvas.scale(scaleFactor);
      }
      canvas.drawPicture(pictureInfo.picture);
      final picture = pictureRecorder.endRecording();

      final image = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      pictureInfo.picture.dispose();
      return image;
    } else {
      final bytes = await file.readAsBytes();

      // Decode the image
      final codec = await instantiateImageCodec(
        bytes,
        targetWidth: size.width.toInt(),
      );
      final frameInfo = await codec.getNextFrame();
      return frameInfo.image;
    }
  }
}
