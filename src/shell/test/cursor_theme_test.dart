import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shell/settings/provider/util/cursor_theme_preview.dart';
import 'package:shell/settings/provider/util/theme_detection.dart';

/// Builds an Xcursor file with one image per entry of [sizes]; every pixel of
/// the image of nominal size `n` is the word `n`, so tests can tell which
/// image was picked.
Uint8List xcursor(List<int> sizes) {
  const tocEntry = 12;
  const chunkHeader = 36;
  final header = 16 + sizes.length * tocEntry;
  final builder = BytesBuilder();
  void word(int value) {
    final data = ByteData(4)..setUint32(0, value, Endian.little);
    builder.add(data.buffer.asUint8List());
  }

  word(0x72756358);
  word(16);
  word(0x10000);
  word(sizes.length);
  var position = header;
  for (final size in sizes) {
    word(0xfffd0002);
    word(size);
    word(position);
    position += chunkHeader + size * size * 4;
  }
  for (final size in sizes) {
    word(chunkHeader);
    word(0xfffd0002);
    word(size);
    word(1);
    word(size); // width
    word(size); // height
    word(0); // xhot
    word(0); // yhot
    word(0); // delay
    for (var i = 0; i < size * size; i++) {
      word(size);
    }
  }
  return builder.toBytes();
}

void main() {
  group('parseXcursor', () {
    test('picks the image whose nominal size is closest', () {
      final image = parseXcursor(xcursor([24, 32, 48]), nominalSize: 30)!;
      expect(image.width, 32);
      expect(image.height, 32);
      expect(image.pixels.length, 32 * 32 * 4);
      expect(
        ByteData.sublistView(image.pixels).getUint32(0, Endian.little),
        32,
      );
    });

    test('rejects data that is not an Xcursor', () {
      expect(parseXcursor(Uint8List.fromList([1, 2, 3, 4, 5])), isNull);
    });

    test('rejects a truncated image', () {
      final bytes = xcursor([24]);
      expect(parseXcursor(Uint8List.sublistView(bytes, 0, 100)), isNull);
    });
  });

  group('cursor themes on disk', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('cursor-themes'));
    tearDown(() => root.deleteSync(recursive: true));

    void theme(String name, {List<int>? arrow, String? inherits}) {
      final directory = Directory(path.join(root.path, 'icons', name))
        ..createSync(recursive: true);
      if (arrow != null) {
        Directory(path.join(directory.path, 'cursors')).createSync();
        File(
          path.join(directory.path, 'cursors', 'left_ptr'),
        ).writeAsBytesSync(xcursor(arrow));
      }
      if (inherits != null) {
        File(
          path.join(directory.path, 'index.theme'),
        ).writeAsStringSync('[Icon Theme]\nInherits=$inherits\n');
      }
    }

    test('lists only themes that ship cursors', () {
      theme('Breeze_Snow', arrow: [24]);
      theme('default', inherits: 'Breeze_Snow');
      theme('Papirus');
      expect(installedCursorThemes(environment: {'XDG_DATA_DIRS': root.path}), {
        'Breeze_Snow',
      });
    });

    test('previews a theme through its Inherits chain', () {
      theme('Breeze_Snow', arrow: [48]);
      theme('default', inherits: 'missing, Breeze_Snow');
      final image = findCursorThemePreview(
        'default',
        baseDirectories: [path.join(root.path, 'icons')],
      );
      expect(image?.width, 48);
    });

    test('survives an inheritance cycle', () {
      theme('a', inherits: 'b');
      theme('b', inherits: 'a');
      expect(
        findCursorThemePreview(
          'a',
          baseDirectories: [path.join(root.path, 'icons')],
        ),
        isNull,
      );
    });
  });
}
