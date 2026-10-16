import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Peak alpha of the frost wash over a live backdrop, shared by the dialog
/// area and the overview background so both read at the same strength.
///
/// The layers differ — the dialog washes the window directly, the overview's
/// wash sits behind the panes — so their visible weight is not identical; split
/// this into per-surface constants if they need to diverge.
const frostedWashAlpha = 20;

/// How much of the theme's `primary` hue the default glass wash
/// ([frostedGlassTint]) carries, out of 255.
///
/// Dial `0` (a pure surface tone) up to `24` to taste. It stays low because the
/// theme uses the `fidelity` seed variant, which keeps the seed's chroma, so a
/// larger alpha reads as painted colour rather than glass.
const glassTintPrimaryAlpha = 16;

/// The default glass wash: a whisper of the primary hue over a base that
/// *raises* contrast with the backdrop — white on a dark scheme (lift the dim
/// desktop) and black on a light one (settle the bright desktop). A wash that
/// always brightened washed out light mode.
Color frostedGlassTint(ColorScheme scheme) => Color.alphaBlend(
  scheme.primary.withAlpha(glassTintPrimaryAlpha),
  scheme.brightness == Brightness.dark ? Colors.white : Colors.black,
);

/// Relative weight of the blur: sigma grows with the frosted region, so a small
/// tile and a large screen read as equally frosted. A fixed sigma blurs a small
/// region proportionally harder.
const _frostSigmaFactor = 0.02;

/// Duration of a frost transition, shared by the frosted surfaces (the dialog
/// backdrop, the overview background and scrim, the gaming pause frost).
///
/// Short and *fully used*: the dialog backdrop used to run a 200ms controller
/// through an `Interval(0, 0.6)`, so the motion really took 120ms while the
/// remaining 80ms only kept rasterizing blurred frames — and on the way out the
/// clamped interval held the frost at full for 80ms before it started to lift,
/// leaving a frozen tile behind an already vanished panel.
const frostDuration = Duration(milliseconds: 160);

/// Curve for a frost ramp. Symmetric, so it needs no `reverseCurve`: with no
/// `Interval` clamping the ends, forward and reverse both start moving on the
/// first frame.
const Curve frostCurve = Curves.easeInOut;

/// Sigma floor: even a tiny region should read as frosted.
const _frostSigmaMin = 8.0;

/// Sigma ceiling: past this the blur only costs raster time.
const _frostSigmaMax = 28.0;

/// Blur sigma to use for a frosted region of [size], clamped so a tiny region
/// is still frosted and a huge one does not blow up the raster cost.
double frostSigmaFor(Size size) => (size.shortestSide * _frostSigmaFactor)
    .clamp(_frostSigmaMin, _frostSigmaMax);

/// Sigma below which the grain is left off: over a sharp image noise just reads
/// as a dirty screen, so grain only belongs on a blurred surface.
const _noiseMinSigma = 1.0;

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
    this.frame = true,
    this.highlight = true,
    this.noise = false,
    this.noiseOpacity = 1,
    this.absorbPointers = false,
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

  /// Hairline frame colour; defaults to a faint outline variant. Ignored when
  /// [frame] is false.
  final Color? borderColor;

  /// Whether to draw the hairline frame at all. A tile backdrop is not a card
  /// and leaves it off.
  final bool frame;

  /// Adds a soft top-to-bottom sheen.
  final bool highlight;

  /// Adds a fine grain that breaks up banding in the wash.
  final bool noise;

  /// How strongly the grain paints, `0`..`1`.
  ///
  /// A caller animating the frost should ramp this with the blur, so the grain
  /// fades in with the wash instead of switching on the instant the blur
  /// crosses [_noiseMinSigma] — a few percent into the ramp, which read as a
  /// pop inside an otherwise smooth transition.
  final double noiseOpacity;

  /// Whether the glass should absorb pointers that its content does not.
  ///
  /// Default `false`: the glass is decorative and must not take a pointer — a
  /// fully transparent wash is still a hit-test-opaque `ColoredBox`, and above
  /// the content it would make the whole area unclickable. Set `true` for a
  /// full-screen backdrop `tintOverContent: false` surface that must swallow
  /// clicks falling outside its content (the overview background).
  final bool absorbPointers;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final frameColor = frame
        ? (borderColor ?? colorScheme.outlineVariant.withAlpha(70))
        : null;

    var content = child;
    if (content != null) {
      // The filters stay in the tree at all times; only what they *do* changes.
      //
      // Inserting or dropping a wrapper around [child] re-inflates everything
      // below it, and the frosted subtree is not a leaf: the overview frosts
      // the whole screen (workspaces, tiles and their live surface widgets),
      // the dialog backdrop a whole tile, the pause frost a running game. A
      // remount there drops their state — and re-runs their focus hand-offs,
      // which steals the keyboard back from whatever the frost was opened for
      // (the overview's search field lost it to the workspace behind it).
      //
      // `ImageFiltered.enabled` is Flutter's way of switching a filter off
      // without touching the tree; the saturation needs the same shape, hence
      // `_SaturationFiltered`.
      content = ImageFiltered(
        enabled: blurSigma > 0.01,
        // Clamp the kernel to the layer's bounds so blurring does not pull
        // transparent edges inward (a halo around the frosted area).
        imageFilter: ui.ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
          tileMode: ui.TileMode.clamp,
        ),
        child: _SaturationFiltered(saturation: saturation, child: content),
      );
    }

    // Only paint the glass when there is something to paint: a closed dialog
    // passes `tint: null` and must not keep drawing a grain over its window.
    // The grain drops out too unless the surface is actually blurred, and is
    // faded by [noiseOpacity] while the frost ramps.
    final showNoise = noise && noiseOpacity > 0 && blurSigma > _noiseMinSigma;
    final hasGlass =
        tint != null || highlight || showNoise || frameColor != null;
    Widget? glass;
    if (hasGlass) {
      Widget layer = _GlassLayer(
        tint: tint,
        frame: frameColor,
        highlight: highlight,
        noise: showNoise,
        noiseOpacity: noiseOpacity,
      );
      // The glass is decorative by default and must not absorb a pointer: a
      // fully transparent veil (alpha 0) is still a hit-test-opaque
      // `ColoredBox`, and above the content it would make the whole frosted
      // area unclickable. A backdrop opts in with [absorbPointers] when it must
      // swallow clicks that land outside its content.
      if (!absorbPointers) {
        layer = IgnorePointer(child: layer);
      }
      glass = layer;
    }

    final stack = Stack(
      fit: StackFit.passthrough,
      children: [
        if (!tintOverContent && glass != null) Positioned.fill(child: glass),
        ?content,
        if (tintOverContent && glass != null) Positioned.fill(child: glass),
      ],
    );

    if (borderRadius == BorderRadius.zero) {
      return stack;
    }
    return ClipRRect(borderRadius: borderRadius, child: stack);
  }
}

/// Applies the frost's vibrancy without touching the element tree.
///
/// `ColorFiltered` cannot be dropped and re-inserted around the content as the
/// frost ramps (see [FrostedSurface.build]), so the filter is applied by a
/// render object of its own: the widget is always in the tree and only the
/// filter it paints changes. At a neutral saturation it is a plain proxy box —
/// no layer, no compositing.
///
/// `ImageFiltered` does the same for the blur through its `enabled` flag; this
/// is that shape for a colour filter.
class _SaturationFiltered extends SingleChildRenderObjectWidget {
  const _SaturationFiltered({required this.saturation, required super.child});

  final double saturation;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSaturationFiltered(saturation);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSaturationFiltered renderObject,
  ) {
    renderObject.saturation = saturation;
  }
}

class _RenderSaturationFiltered extends RenderProxyBox {
  _RenderSaturationFiltered(this._saturation);

  double _saturation;
  double get saturation => _saturation;
  set saturation(double value) {
    if (value == _saturation) {
      return;
    }
    final wasFiltered = _filtered;
    _saturation = value;
    if (wasFiltered != _filtered) {
      // The layer only exists while the vibrancy is lifted, so the parent's
      // compositing bits change with it.
      markNeedsCompositingBitsUpdate();
    }
    markNeedsPaint();
  }

  bool get _filtered => _saturation != 1;

  @override
  bool get alwaysNeedsCompositing => child != null && _filtered;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_filtered) {
      super.paint(context, offset);
      return;
    }
    // Through the framework's `layer` (a ref-counted handle) rather than a
    // field of our own: it keeps the filter layer alive for reuse, where a raw
    // reference would hold one the framework is free to dispose, and reusing a
    // disposed layer asserts.
    layer = context.pushColorFilter(
      offset,
      saturationFilter(_saturation),
      super.paint,
      oldLayer: layer as ColorFilterLayer?,
    );
  }
}

/// The painted glass: wash, sheen, frame and grain, filling its box.
class _GlassLayer extends StatelessWidget {
  const _GlassLayer({
    required this.tint,
    required this.frame,
    required this.highlight,
    required this.noise,
    required this.noiseOpacity,
  });

  final Color? tint;
  final Color? frame;
  final bool highlight;
  final bool noise;
  final double noiseOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (tint != null) ColoredBox(color: tint!),
        if (highlight)
          const DecoratedBox(
            decoration: BoxDecoration(
              // A diagonal sheen, brightest at the top-left corner: a light
              // source grazing the glass, rather than a flat vertical fade.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0, 0.4, 1],
                colors: [
                  Color(0x26FFFFFF),
                  Color(0x00FFFFFF),
                  Color(0x0DFFFFFF),
                ],
              ),
            ),
          ),
        if (frame != null)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.fromBorderSide(BorderSide(color: frame!)),
            ),
          ),
        if (noise) _grainLayer(noiseOpacity),
      ],
    );
  }
}

/// The grain layer, faded by [opacity].
///
/// The grain is a baked image, so its alpha cannot be modulated by the
/// painter's colour: a partial opacity needs a layer, and is skipped entirely
/// once the frost has settled.
Widget _grainLayer(double opacity) => opacity >= 1
    ? const CustomPaint(painter: _NoisePainter())
    : Opacity(
        opacity: opacity,
        child: const CustomPaint(painter: _NoisePainter()),
      );

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
///
/// The grain is baked once into a small tileable image (synchronously, so no
/// async frame is needed) and painted as a repeated shader: one tiled draw
/// instead of a per-paint loop of thousands of rects.
class _NoisePainter extends CustomPainter {
  const _NoisePainter();

  static const _extent = 64;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final grain = _grain();
    if (grain == null) {
      return;
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.ImageShader(
          grain,
          ui.TileMode.repeated,
          ui.TileMode.repeated,
          Float64List.fromList(const <double>[
            1, 0, 0, 0, //
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
          ]),
          // Nearest-neighbour keeps the grain crisp instead of smearing it.
          filterQuality: FilterQuality.none,
        ),
    );
  }

  @override
  bool shouldRepaint(_NoisePainter oldDelegate) => false;
}

ui.Image? _grainCache;
bool _grainFailed = false;

/// The baked grain image, or `null` if the rasterizer refused it (kept
/// deliberately silent: grain is a nicety, not worth failing a frame for).
ui.Image? _grain() {
  final cached = _grainCache;
  if (cached != null || _grainFailed) {
    return cached;
  }
  try {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final random = math.Random(7);
    final paint = Paint()..color = const Color(0x0AFFFFFF);
    // Match the density the per-paint version had (~1 dot per 350px²): the
    // grain should break banding, not read as texture.
    const extent = _NoisePainter._extent;
    final dots = (extent * extent / 350).round();
    for (var i = 0; i < dots; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          random.nextDouble() * extent,
          random.nextDouble() * extent,
          1,
          1,
        ),
        paint,
      );
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      _NoisePainter._extent,
      _NoisePainter._extent,
    );
    picture.dispose();
    _grainCache = image;
    return image;
  } on Object {
    _grainFailed = true;
    return null;
  }
}
