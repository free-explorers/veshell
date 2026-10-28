import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/icon/glyph_outlines.dart';
import 'package:shell/shared/icon/grid_fit.dart';
import 'package:shell/shared/icon/grid_fitted_vector.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

/// A drop-in replacement for [Icon] that stays crisp at fractional scales.
///
/// [Icon] draws its glyph as text, so at a scale such as 1.2 the glyph's
/// straight edges fall between pixels and every symbol looks soft. This
/// widget reads the same glyph's outline from the same (tree-shaken) icon font
/// and draws it grid-fitted: at the exact size, with its straight edges on
/// whole pixels (see `grid_fit.dart`).
///
/// Sizing, colour, opacity, text scaling, right-to-left mirroring and
/// semantics follow [Icon] and the ambient [IconTheme]. While the outline is
/// loading (the first time a font is used), or when it cannot be read, the
/// regular [Icon] is drawn instead.
class ShellIcon extends HookWidget {
  const ShellIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.textDirection,
  });

  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    var iconSize = size ?? iconTheme.size ?? kDefaultFontSize;
    if (iconTheme.applyTextScaling ?? false) {
      iconSize = MediaQuery.textScalerOf(context).scale(iconSize);
    }
    var iconColor = color ?? iconTheme.color ?? const Color(0xFF000000);
    if (iconTheme.opacity != null && iconTheme.opacity != 1) {
      iconColor = iconColor.withValues(alpha: iconColor.a * iconTheme.opacity!);
    }

    final icon = this.icon;
    final outline = useMemoized(
      () => icon == null ? null : GlyphOutlines.instance.outline(icon),
      [icon],
    );
    final loaded = useFuture(
      outline is Future<vg.VectorInstructions?> ? outline : null,
    );
    final instructions = outline is vg.VectorInstructions
        ? outline
        : loaded.data;

    Widget child;
    if (icon == null) {
      child = SizedBox.square(dimension: iconSize);
    } else if (instructions == null || !isGridFittable(instructions)) {
      child = Icon(
        icon,
        size: iconSize,
        color: iconColor,
        textDirection: textDirection,
      );
    } else {
      // Like `Icon`: a box of the icon's size, the glyph centred in it at
      // that size even when the parent forces the box larger or smaller.
      child = SizedBox.square(
        dimension: iconSize,
        child: OverflowBox(
          minWidth: iconSize,
          maxWidth: iconSize,
          minHeight: iconSize,
          maxHeight: iconSize,
          child: GridFittedVector(
            instructions: instructions,
            size: iconSize,
            color: iconColor,
          ),
        ),
      );
      final direction = textDirection ?? Directionality.maybeOf(context);
      if (icon.matchTextDirection && direction == TextDirection.rtl) {
        child = Transform.flip(flipX: true, child: child);
      }
    }

    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(child: child),
    );
  }
}
