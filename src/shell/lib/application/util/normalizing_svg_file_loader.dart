import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shell/application/util/svg_css_inliner.dart';

/// An [SvgLoader] that reads [file], inlines its embedded CSS, and then hands
/// the result to the usual `vector_graphics` compiler and cache.
///
/// `SvgPicture.file` uses [SvgFileLoader], which feeds the raw document to a
/// parser that ignores `<style>` elements and `class` selectors. This loader
/// runs [inlineSvgCss] first, so stylesheet-styled icons - the Code - OSS icon
/// among them - keep their fills instead of rendering as a black square.
///
/// The (small) file read happens on the caller's isolate; the SVG parse and
/// tessellation still run in flutter_svg's isolate through the inherited
/// [SvgLoader] machinery, and the encoded result is cached by
/// [SvgLoader.cacheKey]. Equality is by path, theme and colour mapper, so a
/// rebuild that constructs a fresh [File] for the same path still hits the
/// cache instead of re-parsing the icon.
class NormalizingSvgFileLoader extends SvgLoader<String> {
  const NormalizingSvgFileLoader(this.file, {super.theme, super.colorMapper});

  final File file;

  @override
  Future<String?> prepareMessage(BuildContext? context) async {
    final bytes = await file.readAsBytes();
    return inlineSvgCss(utf8.decode(bytes, allowMalformed: true));
  }

  @override
  String provideSvg(String? message) => message ?? '';

  @override
  bool operator ==(Object other) =>
      other is NormalizingSvgFileLoader &&
      other.file.path == file.path &&
      other.theme == theme &&
      other.colorMapper == colorMapper;

  @override
  int get hashCode => Object.hash(file.path, theme, colorMapper);
}
