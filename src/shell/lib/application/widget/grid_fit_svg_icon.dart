import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/util/normalizing_svg_file_loader.dart';
import 'package:shell/application/util/svg_css_inliner.dart';
import 'package:shell/shared/icon/grid_fit.dart';
import 'package:shell/shared/icon/grid_fitted_vector.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

/// An SVG icon file drawn grid-fitted (see `grid_fit.dart`): crisp at the
/// exact size, whatever the icon theme and the display scale.
///
/// The file is parsed once, off the UI isolate, with the same CSS inlining and
/// normalization as [NormalizingSvgFileLoader]. An icon that uses what the
/// fitter cannot draw (masks, text, embedded images, patterns), or that fails
/// to parse, is drawn by flutter_svg as before.
class GridFitSvgIcon extends HookWidget {
  const GridFitSvgIcon({required this.file, required this.size, super.key});

  final File file;
  final double size;

  @override
  Widget build(BuildContext context) {
    final future = useMemoized(() => _SvgIconCache.load(file), [file.path]);
    final cached = _SvgIconCache.peek(file);
    final snapshot = useFuture(future, initialData: cached);
    if (snapshot.connectionState != ConnectionState.done && cached == null) {
      return SizedBox.square(dimension: size);
    }
    final instructions = snapshot.data ?? cached;
    if (instructions == null || !isGridFittable(instructions)) {
      return SvgPicture(NormalizingSvgFileLoader(file));
    }
    return Center(
      child: GridFittedVector(instructions: instructions, size: size),
    );
  }
}

/// Parsed icon files, by path. Icon files are few and their parse is the
/// expensive part; the fitted pictures are cached by `GridFittedVector`.
abstract final class _SvgIconCache {
  static final _parsed = <String, vg.VectorInstructions?>{};
  static final _pending = <String, Future<vg.VectorInstructions?>>{};

  static vg.VectorInstructions? peek(File file) => _parsed[file.path];

  static Future<vg.VectorInstructions?> load(File file) {
    final path = file.path;
    if (_parsed.containsKey(path)) return Future.value(_parsed[path]);
    return _pending.putIfAbsent(path, () async {
      vg.VectorInstructions? instructions;
      try {
        final xml = normalizeSvgFontWeight(
          inlineSvgCss(
            utf8.decode(await file.readAsBytes(), allowMalformed: true),
          ),
        );
        instructions = await Isolate.run(
          () => vg.parseWithoutOptimizers(xml, key: path),
        );
      } on Object catch (error) {
        iconLog.fine('Grid fitting skipped for $path: $error');
      }
      _parsed[path] = instructions;
      unawaited(_pending.remove(path));
      return instructions;
    });
  }
}
