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
  @override
  Future<Image?> build(IconQuery query, Size size) async {
    final image = await _decode(query, size);
    if (image == null) {
      return null;
    }
    // Disposed while decoding: nothing can display this image, so free it.
    if (!ref.mounted) {
      image.dispose();
      return null;
    }
    ref.onDispose(image.dispose);
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
