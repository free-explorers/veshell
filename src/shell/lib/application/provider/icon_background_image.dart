import 'dart:io';
import 'dart:ui';

import 'package:flutter_svg/svg.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/icon_file_from_query.dart';
import 'package:shell/application/util/normalizing_svg_file_loader.dart';

part 'icon_background_image.g.dart';

/// Resolution the baked placeholder background is rendered at.
///
/// It is deliberately small: the result is stretched over the whole
/// placeholder, and the icon is only a wash of colour.
const _textureSize = 64;

/// Size the icon is decoded at before it is stretched over [_textureSize].
///
/// The placeholder used to decode the icon at 4 px and blur the stretched
/// result, so a 4 px source keeps the same soft look.
const _sourceSize = 4;

/// How far the icon is stretched past the texture on every side, as a fraction
/// of the texture.
///
/// The placeholder used to overscan the icon with a negative-margin
/// `Positioned.fill`: the icon was drawn 1.6x larger than the placeholder and
/// only its centre was visible, which is what keeps the icon's transparent
/// edges and corners out of the placeholder. Baking the blur without that
/// overscan shows those corners (black) in the placeholder. The fraction
/// matches the old `0.3` margins.
const _overscan = 0.3;

/// Blur applied to the baked background.
const _sigma = 10.0;

/// The ambient app-icon background of a window placeholder, blurred once.
///
/// The placeholder used to wrap a live `ImageFiltered` with a sigma-300 blur
/// around the stretched icon. The engine expands a blur's paint bounds by
/// roughly three times its sigma — here about 900 logical pixels on every side
/// (see `ImageFilterLayer::Preroll`) — so each time the desktop was
/// re-rasterised, which the overview forces, it allocated a huge offscreen
/// surface and blurred it every frame.
///
/// Baking the blur into a small image keeps the look and turns the per-frame
/// cost into a plain texture draw.
@riverpod
Future<Image?> iconBackgroundImage(Ref ref, String path) async {
  final file = await ref.watch(
    iconFileFromQueryProvider(
      IconQuery(
        name: path,
        size: _sourceSize,
        extensions: const ['svg', 'png'],
      ),
    ).future,
  );
  if (file == null) {
    return null;
  }

  final icon = await _decode(file, _sourceSize);
  if (icon == null) {
    return null;
  }

  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  // Draw the icon oversized and centred, so only its centre lands in the
  // texture: the same overscan the placeholder used to get from its negative
  // margins. `TileMode.clamp` then extends the edge pixels instead of fading
  // to transparent, so stretching the texture over the placeholder has no soft
  // border.
  const inset = _textureSize * _overscan;
  const side = _textureSize + 2 * inset;
  canvas.drawImageRect(
    icon,
    Rect.fromLTWH(0, 0, icon.width.toDouble(), icon.height.toDouble()),
    const Rect.fromLTWH(-inset, -inset, side, side),
    Paint()
      ..filterQuality = FilterQuality.high
      ..imageFilter = ImageFilter.blur(
        sigmaX: _sigma,
        sigmaY: _sigma,
        tileMode: TileMode.clamp,
      ),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(_textureSize, _textureSize);
  picture.dispose();
  // The decoded icon only existed to be baked into [image]; release it now
  // rather than retaining a native image per placeholder.
  icon.dispose();
  ref.onDispose(image.dispose);
  return image;
}

/// Decode [file] into a native image [size] pixels on each side.
///
/// This is the small amount of decoding the icon pipeline still needs: the
/// placeholder bake genuinely consumes a `ui.Image`, unlike the app icons,
/// which are painted by `Image`/`SvgPicture` and cached by Flutter.
Future<Image?> _decode(File file, int size) async {
  if (file.path.endsWith('.svg')) {
    final pictureInfo = await vg.loadPicture(
      NormalizingSvgFileLoader(file),
      null,
    );
    final pictureRecorder = PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    // Scale the vector to the target size before rasterising.
    final scaleFactor = size / pictureInfo.size.width;
    if (scaleFactor != 0) {
      canvas.scale(scaleFactor);
    }
    canvas.drawPicture(pictureInfo.picture);
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size, size);
    pictureInfo.picture.dispose();
    return image;
  }

  final bytes = await file.readAsBytes();
  final codec = await instantiateImageCodec(bytes, targetWidth: size);
  final frameInfo = await codec.getNextFrame();
  return frameInfo.image;
}
