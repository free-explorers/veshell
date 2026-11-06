import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shell/application/provider/png_pixel_size.dart';

Uint8List _header({
  required int width,
  required int height,
  String chunk = 'IHDR',
}) {
  final bytes = Uint8List(24)
    ..setAll(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final data = ByteData.sublistView(bytes)..setUint32(8, 13);
  bytes.setAll(12, chunk.codeUnits);
  data
    ..setUint32(16, width)
    ..setUint32(20, height);
  return bytes;
}

void main() {
  test('reads the size from the IHDR chunk', () {
    expect(
      readPngPixelSize(_header(width: 50, height: 48)),
      const Size(50, 48),
    );
  });

  test('rejects what is not a PNG header', () {
    expect(readPngPixelSize(Uint8List(10)), isNull);
    expect(readPngPixelSize(Uint8List(24)), isNull);
    expect(
      readPngPixelSize(_header(width: 1, height: 1, chunk: 'IDAT')),
      isNull,
    );
  });
}
