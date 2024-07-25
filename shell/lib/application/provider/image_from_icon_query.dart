import 'dart:ui';

import 'package:flutter_svg/svg.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/icon_themes.dart';

part 'image_from_icon_query.g.dart';

@Riverpod(keepAlive: true)
class ImageFromIconQuery extends _$ImageFromIconQuery {
  @override
  Future<Image?> build(IconQuery query, Size size) async {
    final themes = await ref.watch(iconThemesProvider.future);
    print('after theme loads');
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
      final codec =
          await instantiateImageCodec(bytes, targetWidth: size.width.toInt());
      final frameInfo = await codec.getNextFrame();
      return frameInfo.image;
    }
  }
}
