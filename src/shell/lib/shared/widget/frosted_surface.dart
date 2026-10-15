import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// A frosted-glass surface: [child] can be blurred and its saturation lifted,
/// then a translucent wash, a hairline frame, a top sheen and (optionally) a
/// fine grain are drawn as the glass itself.
///
/// Two layering modes, chosen by [tintOverContent]:
///
/// * default — the glass sits *behind* the content, a background for
///   transparent UI (the overview panes);
/// * [tintOverContent] — the glass sits *above* the content, a veil that dims
///   what it frosts (the window behind a tile's dialog area).
///
/// The saturation is applied to [child], so a panel of UI should leave
/// [saturation] at `1`; it is meant for the blurred backdrop.
class FrostedSurface extends StatelessWidget {
  const FrostedSurface({
    this.child,
    this.borderRadius = BorderRadius.zero,
    this.blurSigma = 0,
    this.saturation = 1,
    this.tint,
    this.tintOverContent = false,
    this.borderColor,
    this.highlight = true,
    this.noise = false,
    super.key,
  });

  final Widget? child;

  /// Corner radius; also clips the glass and the blurred content.
  final BorderRadius borderRadius;

  /// Gaussian blur sigma applied to [child]. `0` leaves it sharp.
  final double blurSigma;

  /// Saturation factor applied to [child]; `1` leaves it unchanged, `> 1`
  /// lifts it (the "vibrancy" half of frosted glass).
  final double saturation;

  /// Translucent wash drawn as the glass.
  final Color? tint;

  /// Draws the glass above [child] instead of behind it.
  final bool tintOverContent;

  /// Hairline frame colour; defaults to a faint outline variant.
  final Color? borderColor;

  /// Adds a soft top-to-bottom sheen.
  final bool highlight;

  /// Adds a fine grain that breaks up banding in the wash.
  final bool noise;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final frame = borderColor ?? colorScheme.outlineVariant.withAlpha(70);

    var content = child;
    if (content != null && blurSigma > 0.01) {
      content = ImageFiltered(
        // Clamp the kernel to the layer's bounds so blurring does not pull
        // transparent edges inward (a halo around the frosted area).
        imageFilter: ui.ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
          tileMode: ui.TileMode.clamp,
        ),
        child: content,
      );
    }
    if (content != null && saturation != 1) {
      content = ColorFiltered(
        colorFilter: saturationFilter(saturation),
        child: content,
      );
    }

    // The glass is decorative and must never absorb a pointer: a fully
    // transparent veil (alpha 0) is still a hit-test-opaque `ColoredBox`, and
    // sitting above the content it would make the whole frosted area
    // unclickable.
    final glass = IgnorePointer(
      child: _GlassLayer(
        tint: tint,
        frame: frame,
        highlight: highlight,
        noise: noise,
      ),
    );

    final stack = Stack(
      fit: StackFit.passthrough,
      children: [
        if (!tintOverContent) Positioned.fill(child: glass),
        ?content,
        if (tintOverContent) Positioned.fill(child: glass),
      ],
    );

    if (borderRadius == BorderRadius.zero) {
      return stack;
    }
    return ClipRRect(borderRadius: borderRadius, child: stack);
  }
}

/// The painted glass: wash, sheen, frame and grain, filling its box.
class _GlassLayer extends StatelessWidget {
  const _GlassLayer({
    required this.tint,
    required this.frame,
    required this.highlight,
    required this.noise,
  });

  final Color? tint;
  final Color frame;
  final bool highlight;
  final bool noise;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (tint != null) ColoredBox(color: tint!),
        if (highlight)
          const DecoratedBox(
            decoration: BoxDecoration(
              // A faint sheen from the top edge; sells the pane of glass.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x14FFFFFF), Color(0x00FFFFFF)],
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.fromBorderSide(BorderSide(color: frame)),
          ),
        ),
        if (noise) const CustomPaint(painter: _NoisePainter()),
      ],
    );
  }
}

/// A saturation matrix filter. `amount` of `1` is identity, `> 1` boosts.
ColorFilter saturationFilter(double amount) {
  const lumR = 0.2126;
  const lumG = 0.7152;
  const lumB = 0.0722;
  final inv = 1 - amount;
  return ColorFilter.matrix(<double>[
    inv * lumR + amount, inv * lumG, inv * lumB, 0, 0, //
    inv * lumR, inv * lumG + amount, inv * lumB, 0, 0,
    inv * lumR, inv * lumG, inv * lumB + amount, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}

/// A sparse, deterministic grain: enough to break the banding a flat wash
/// shows on a gradient, light enough not to read as texture.
class _NoisePainter extends CustomPainter {
  const _NoisePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final random = math.Random(7);
    final paint = Paint()..color = const Color(0x0AFFFFFF);
    final count = (size.width * size.height / 350).clamp(0, 4000).toInt();
    for (var i = 0; i < count; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
          1,
          1,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_NoisePainter oldDelegate) => false;
}
