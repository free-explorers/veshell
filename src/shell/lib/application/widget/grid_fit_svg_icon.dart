import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/util/normalizing_svg_file_loader.dart';
import 'package:shell/application/util/svg_css_inliner.dart';
import 'package:shell/application/util/symbolic_svg.dart';
import 'package:shell/shared/icon/grid_fit.dart';
import 'package:shell/shared/icon/grid_fitted_vector.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:vector_graphics/vector_graphics_compat.dart'
    show RenderingStrategy;
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

/// An SVG icon file drawn grid-fitted (see `grid_fit.dart`): crisp at the
/// exact size, whatever the icon theme and the display scale.
///
/// The file is parsed once, off the UI isolate, with the same CSS inlining and
/// normalization as [NormalizingSvgFileLoader]. An icon that uses what the
/// fitter cannot draw (masks, text, embedded images, patterns), or that fails
/// to parse, is drawn by flutter_svg as before.
///
/// A symbolic icon (see [isSymbolicSvg]) is tinted with the ambient
/// [IconTheme] colour, as GTK and Plasma draw them in their surface's
/// foreground colour: its own colour is a dark placeholder.
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
    final icon = snapshot.data ?? cached;
    final tint = icon != null && icon.symbolic
        ? IconTheme.of(context).color
        : null;
    final instructions = icon?.instructions;
    if (instructions == null || !isGridFittable(instructions)) {
      return SvgPicture(
        NormalizingSvgFileLoader(file),
        // Rasterized (multisampled, once) rather than drawn as aliased
        // paths: see GridFittedVector.
        renderingStrategy: RenderingStrategy.raster,
        colorFilter: tint == null
            ? null
            : ColorFilter.mode(tint, BlendMode.srcIn),
      );
    }
    return Center(
      child: GridFittedVector(
        instructions: instructions,
        size: size,
        color: tint,
      ),
    );
  }
}

/// A parsed icon file: its instructions (`null` when it failed to parse) and
/// whether it is symbolic.
typedef _ParsedSvgIcon = ({vg.VectorInstructions? instructions, bool symbolic});

/// Parsed icon files, by path. Icon files are few and their parse is the
/// expensive part; the fitted pictures are cached by `GridFittedVector`.
abstract final class _SvgIconCache {
  static final _parsed = <String, _ParsedSvgIcon>{};
  static final _pending = <String, Future<_ParsedSvgIcon>>{};

  static _ParsedSvgIcon? peek(File file) => _parsed[file.path];

  static Future<_ParsedSvgIcon> load(File file) {
    final path = file.path;
    final parsed = _parsed[path];
    if (parsed != null) return Future.value(parsed);
    return _pending.putIfAbsent(path, () async {
      vg.VectorInstructions? instructions;
      // Known from the name alone should the file fail to read.
      var symbolic = isSymbolicSvg(path, '');
      try {
        final source = utf8.decode(
          await file.readAsBytes(),
          allowMalformed: true,
        );
        symbolic = isSymbolicSvg(path, source);
        final xml = normalizeSvgFontWeight(inlineSvgCss(source));
        instructions = await Isolate.run(
          () => vg.parseWithoutOptimizers(xml, key: path),
        );
      } on Object catch (error) {
        iconLog.fine('Grid fitting skipped for $path: $error');
      }
      final result = (instructions: instructions, symbolic: symbolic);
      _parsed[path] = result;
      unawaited(_pending.remove(path));
      return result;
    });
  }
}
