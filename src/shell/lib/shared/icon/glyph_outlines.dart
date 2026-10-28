import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

/// Outlines of icon-font glyphs, read from the fonts bundled with the app.
///
/// `ShellIcon` grid-fits symbol icons, which needs their geometry: Flutter
/// draws an `Icon` as text and gives no access to the glyph's shape. The
/// outline is read from the same font asset the `Icon` would use, so release
/// builds keep tree-shaking icon fonts down to the glyphs the code references.
///
/// TrueType (`glyf`) outlines only: a CFF font, a composite glyph or a
/// missing glyph yields `null`, and the caller falls back to `Icon`.
class GlyphOutlines {
  GlyphOutlines._();

  static final instance = GlyphOutlines._();

  /// Overrides how font assets are read (tests).
  @visibleForTesting
  Future<ByteData> Function(String key) loadAsset = rootBundle.load;

  Future<Map<String, String>>? _manifest;
  final _fonts = <String, Future<_TrueTypeFont?>>{};
  final _glyphs = <(String, int), vg.VectorInstructions?>{};

  /// The glyph of [icon] if it is already known (`null` when unavailable),
  /// or a future of it.
  FutureOr<vg.VectorInstructions?> outline(IconData icon) {
    final family = _familyKey(icon);
    final key = (family, icon.codePoint);
    if (_glyphs.containsKey(key)) return _glyphs[key];
    return _load(family, icon.codePoint).then((glyph) => _glyphs[key] = glyph);
  }

  /// Forgets everything loaded (tests).
  @visibleForTesting
  void reset() {
    _manifest = null;
    _fonts.clear();
    _glyphs.clear();
  }

  static String _familyKey(IconData icon) => icon.fontPackage == null
      ? icon.fontFamily ?? ''
      : 'packages/${icon.fontPackage}/${icon.fontFamily}';

  Future<vg.VectorInstructions?> _load(String family, int codePoint) async {
    final font = await _fonts.putIfAbsent(family, () => _loadFont(family));
    return font?.glyph(codePoint);
  }

  Future<_TrueTypeFont?> _loadFont(String family) async {
    try {
      final manifest = await (_manifest ??= _loadManifest());
      final asset = manifest[family];
      if (asset == null) return null;
      return _TrueTypeFont.parse(await loadAsset(asset));
    } on Object catch (error) {
      iconLog.warning('Cannot read the outlines of font "$family": $error');
      return null;
    }
  }

  Future<Map<String, String>> _loadManifest() async {
    final data = await loadAsset('FontManifest.json');
    final json =
        jsonDecode(
              utf8.decode(
                data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
              ),
            )
            as List<dynamic>;
    return {
      for (final entry in json.cast<Map<String, dynamic>>())
        if ((entry['fonts'] as List<dynamic>).isNotEmpty)
          entry['family'] as String:
              ((entry['fonts'] as List<dynamic>).first
                      as Map<String, dynamic>)['asset']
                  as String,
    };
  }
}

/// The parts of a TrueType font needed to draw a glyph: `cmap` (code point to
/// glyph), `loca`/`glyf` (outlines), `hmtx` (advance), `hhea` (the line box).
class _TrueTypeFont {
  _TrueTypeFont._(this._data, this._tables);

  static _TrueTypeFont? parse(ByteData data) {
    final count = data.getUint16(4);
    final tables = <String, (int, int)>{};
    for (var i = 0; i < count; i++) {
      final record = 12 + 16 * i;
      final tag = String.fromCharCodes([
        for (var j = 0; j < 4; j++) data.getUint8(record + j),
      ]);
      tables[tag] = (data.getUint32(record + 8), data.getUint32(record + 12));
    }
    const required = ['head', 'hhea', 'maxp', 'cmap', 'loca', 'glyf', 'hmtx'];
    for (final tag in required) {
      if (!tables.containsKey(tag)) return null;
    }
    return _TrueTypeFont._(data, tables).._readHeaders();
  }

  final ByteData _data;
  final Map<String, (int, int)> _tables;
  late final int _longOffsets;
  late final int _ascender;
  late final int _descender;
  late final int _glyphCount;
  late final int _metricsCount;
  final _codePoints = <int, int>{};

  int _table(String tag) => _tables[tag]!.$1;

  void _readHeaders() {
    _longOffsets = _data.getInt16(_table('head') + 50);
    _ascender = _data.getInt16(_table('hhea') + 4);
    _descender = _data.getInt16(_table('hhea') + 6);
    _metricsCount = _data.getUint16(_table('hhea') + 34);
    _glyphCount = _data.getUint16(_table('maxp') + 4);
    _readCmap();
  }

  void _readCmap() {
    final cmap = _table('cmap');
    final count = _data.getUint16(cmap + 2);
    for (var i = 0; i < count; i++) {
      final subtable = cmap + _data.getUint32(cmap + 4 + 8 * i + 4);
      switch (_data.getUint16(subtable)) {
        case 12:
          final groups = _data.getUint32(subtable + 12);
          for (var g = 0; g < groups; g++) {
            final group = subtable + 16 + 12 * g;
            final start = _data.getUint32(group);
            final end = _data.getUint32(group + 4);
            final glyph = _data.getUint32(group + 8);
            for (var c = start; c <= end; c++) {
              _codePoints[c] = glyph + c - start;
            }
          }
        case 4:
          final segments = _data.getUint16(subtable + 6) ~/ 2;
          final ends = subtable + 14;
          final starts = ends + 2 * segments + 2;
          final deltas = starts + 2 * segments;
          final ranges = deltas + 2 * segments;
          for (var s = 0; s < segments; s++) {
            final start = _data.getUint16(starts + 2 * s);
            final end = _data.getUint16(ends + 2 * s);
            final delta = _data.getInt16(deltas + 2 * s);
            final range = _data.getUint16(ranges + 2 * s);
            for (var c = start; c <= end && c != 0xFFFF; c++) {
              int glyph;
              if (range == 0) {
                glyph = (c + delta) & 0xFFFF;
              } else {
                final at = ranges + 2 * s + range + 2 * (c - start);
                glyph = _data.getUint16(at);
                if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
              }
              _codePoints.putIfAbsent(c, () => glyph);
            }
          }
      }
    }
  }

  int _glyphOffset(int glyph) {
    final loca = _table('loca');
    return _longOffsets == 0
        ? _data.getUint16(loca + 2 * glyph) * 2
        : _data.getUint32(loca + 4 * glyph);
  }

  int _advance(int glyph) {
    final hmtx = _table('hmtx');
    final index = glyph < _metricsCount ? glyph : _metricsCount - 1;
    return _data.getUint16(hmtx + 4 * index);
  }

  /// The glyph for [codePoint] as drawing commands in a box of its advance
  /// by the font's line height, the box `Icon` lays the glyph out in.
  vg.VectorInstructions? glyph(int codePoint) {
    final glyph = _codePoints[codePoint];
    if (glyph == null || glyph == 0 || glyph >= _glyphCount) return null;
    final start = _glyphOffset(glyph);
    final end = _glyphOffset(glyph + 1);
    if (end <= start) return null;
    final at = _table('glyf') + start;
    final contourCount = _data.getInt16(at);
    // Composite glyphs reference other glyphs; icon fonts rarely use them.
    if (contourCount < 0) return null;
    final contours = _simpleGlyph(at, contourCount);
    final width = _advance(glyph).toDouble();
    final height = (_ascender - _descender).toDouble();
    if (width <= 0 || height <= 0) return null;
    final path = StringBuffer();
    String p(double x, double y) =>
        '${x.toStringAsFixed(2)} ${(_ascender - y).toStringAsFixed(2)}';
    for (final contour in contours) {
      if (contour.isEmpty) continue;
      // Start on an on-curve point, or between two off-curve ones.
      var points = contour;
      final firstOn = points.indexWhere((point) => point.$3);
      (double, double) begin;
      if (firstOn < 0) {
        final a = points.first;
        final b = points.last;
        begin = ((a.$1 + b.$1) / 2, (a.$2 + b.$2) / 2);
      } else {
        points = [...points.sublist(firstOn), ...points.sublist(0, firstOn)];
        begin = (points.first.$1, points.first.$2);
        points = points.sublist(1);
      }
      path.write('M${p(begin.$1, begin.$2)}');
      (double, double)? control;
      for (final (x, y, on) in [...points, (begin.$1, begin.$2, true)]) {
        if (on) {
          path.write(
            control == null
                ? 'L${p(x, y)}'
                : 'Q${p(control.$1, control.$2)} ${p(x, y)}',
          );
          control = null;
        } else {
          if (control != null) {
            final mx = (control.$1 + x) / 2;
            final my = (control.$2 + y) / 2;
            path.write('Q${p(control.$1, control.$2)} ${p(mx, my)}');
          }
          control = (x, y);
        }
      }
      path.write('Z');
    }
    return vg.parseWithoutOptimizers(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $width $height" '
      'width="$width" height="$height"><path fill="#000" d="$path"/></svg>',
    );
  }

  List<List<(double, double, bool)>> _simpleGlyph(int at, int contourCount) {
    final ends = [
      for (var i = 0; i < contourCount; i++) _data.getUint16(at + 10 + 2 * i),
    ];
    if (ends.isEmpty) return const [];
    var p = at + 10 + 2 * contourCount;
    p += 2 + _data.getUint16(p);
    final pointCount = ends.last + 1;
    final flags = <int>[];
    while (flags.length < pointCount) {
      final flag = _data.getUint8(p++);
      flags.add(flag);
      if (flag & 8 != 0) {
        final repeat = _data.getUint8(p++);
        for (var r = 0; r < repeat; r++) {
          flags.add(flag);
        }
      }
    }
    List<double> coordinates(int short, int same) {
      var value = 0;
      final out = <double>[];
      for (final flag in flags.take(pointCount)) {
        if (flag & short != 0) {
          final delta = _data.getUint8(p++);
          value += flag & same != 0 ? delta : -delta;
        } else if (flag & same == 0) {
          value += _data.getInt16(p);
          p += 2;
        }
        out.add(value.toDouble());
      }
      return out;
    }

    final xs = coordinates(2, 16);
    final ys = coordinates(4, 32);
    final contours = <List<(double, double, bool)>>[];
    var first = 0;
    for (final end in ends) {
      contours.add([
        for (var i = first; i <= end; i++) (xs[i], ys[i], flags[i] & 1 != 0),
      ]);
      first = end + 1;
    }
    return contours;
  }
}
