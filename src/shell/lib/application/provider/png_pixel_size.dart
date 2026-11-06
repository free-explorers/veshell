import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'png_pixel_size.g.dart';

const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// The pixel size of the PNG at [path], from its header; `null` when the file
/// cannot be read or is not a PNG.
///
/// Kept alive: one entry per icon file, read once (the first 24 bytes), so the
/// icon widgets can tell a low-resolution icon apart without decoding it.
@Riverpod(keepAlive: true)
Size? pngPixelSize(Ref ref, String path) {
  try {
    final file = File(path).openSync();
    try {
      return readPngPixelSize(file.readSync(24));
    } finally {
      file.closeSync();
    }
  } on FileSystemException {
    return null;
  }
}

/// The width and height in a PNG's header [bytes] (the signature, then the
/// `IHDR` chunk); `null` when they are not one.
Size? readPngPixelSize(Uint8List bytes) {
  if (bytes.length < 24) {
    return null;
  }
  for (final (index, byte) in _pngSignature.indexed) {
    if (bytes[index] != byte) {
      return null;
    }
  }
  if (String.fromCharCodes(bytes, 12, 16) != 'IHDR') {
    return null;
  }
  final data = ByteData.sublistView(bytes);
  return Size(data.getUint32(16).toDouble(), data.getUint32(20).toDouble());
}
