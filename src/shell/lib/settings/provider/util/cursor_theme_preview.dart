import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:shell/settings/provider/util/theme_detection.dart';

/// Cursor names tried for a theme's preview, in order: the arrow under its
/// freedesktop name, then the legacy X11 names themes still ship.
const cursorThemePreviewNames = ['default', 'left_ptr', 'arrow'];

/// One frame of an Xcursor file, as premultiplied BGRA bytes.
///
/// The Xcursor pixel is a little-endian `0xAARRGGBB` word, so its bytes are
/// already in `bgra8888` order with premultiplied alpha, which is what
/// `decodeImageFromPixels` takes.
class CursorImage {
  const CursorImage({
    required this.width,
    required this.height,
    required this.pixels,
  });

  final int width;
  final int height;
  final Uint8List pixels;
}

const _magic = 0x72756358; // "Xcur", little-endian.
const _imageType = 0xfffd0002;

/// Decodes the frame of [bytes] (an Xcursor file) whose nominal size is
/// closest to [nominalSize], or `null` when the data is not a valid Xcursor.
CursorImage? parseXcursor(Uint8List bytes, {int nominalSize = 32}) {
  final data = ByteData.sublistView(bytes);
  int? read(int offset) => offset + 4 <= data.lengthInBytes
      ? data.getUint32(offset, Endian.little)
      : null;

  if (read(0) != _magic) return null;
  final headerSize = read(4);
  final count = read(12);
  if (headerSize == null || count == null) return null;

  int? bestPosition;
  int? bestDistance;
  for (var i = 0; i < count; i++) {
    final entry = headerSize + i * 12;
    final type = read(entry);
    final size = read(entry + 4);
    final position = read(entry + 8);
    if (type == null || size == null || position == null) return null;
    if (type != _imageType) continue;
    final distance = (size - nominalSize).abs();
    if (bestDistance == null || distance < bestDistance) {
      bestDistance = distance;
      bestPosition = position;
    }
  }
  if (bestPosition == null) return null;

  // Chunk header: header size, type, subtype, version, then the image's
  // width, height, x/y hotspot and delay.
  final chunkHeader = read(bestPosition);
  final width = read(bestPosition + 16);
  final height = read(bestPosition + 20);
  if (chunkHeader == null || width == null || height == null) return null;
  if (width == 0 || height == 0 || width > 0x7fff || height > 0x7fff) {
    return null;
  }
  final start = bestPosition + chunkHeader;
  final end = start + width * height * 4;
  if (end > bytes.length) return null;
  return CursorImage(
    width: width,
    height: height,
    pixels: Uint8List.fromList(bytes.sublist(start, end)),
  );
}

/// The arrow of cursor [theme], following its `Inherits` chain, or `null` when
/// none of [names] resolves.
CursorImage? findCursorThemePreview(
  String theme, {
  List<String> names = cursorThemePreviewNames,
  List<String>? baseDirectories,
  int nominalSize = 32,
}) {
  final bases = baseDirectories ?? iconThemeBaseDirectories();
  final visited = <String>{};
  final queue = [theme];
  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    if (!visited.add(current)) continue;
    for (final base in bases) {
      for (final name in names) {
        final file = File(path.join(base, current, 'cursors', name));
        if (!file.existsSync()) continue;
        final image = parseXcursor(
          file.readAsBytesSync(),
          nominalSize: nominalSize,
        );
        if (image != null) return image;
      }
    }
    queue.addAll(themeInherits(current, bases));
  }
  return null;
}
