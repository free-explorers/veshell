import 'package:material_ui/material_ui.dart';
import 'package:shell/application/util/application_symbol.dart';

/// A typographic stand-in for an application icon.
///
/// The badge shows a periodic-table style symbol of the application name
/// (`Firefox` → `Fi`), on a colour derived from the full name so neighbouring
/// apps stay distinguishable, tinted by the theme's primary colour so the
/// badges belong to the current palette. It
/// sizes itself to the tight box it is given, which is how every icon site in
/// the shell already constrains its icon.
class LetterAppIcon extends StatelessWidget {
  const LetterAppIcon({required this.title, super.key});

  /// The application title; only its symbol is painted.
  final String title;

  @override
  Widget build(BuildContext context) {
    final symbol = applicationSymbol(title);
    final background = letterIconColor(
      title,
      Theme.of(context).colorScheme.primary,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        if (!size.isFinite || size <= 0) return const SizedBox.shrink();

        return Semantics(
          label: title,
          image: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(size * 0.22),
            ),
            child: Center(
              child: Text(
                symbol,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: Colors.white,
                  // Two letters need a smaller size to keep the same margins.
                  fontSize: size * (symbol.runes.length > 1 ? 0.42 : 0.52),
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A stable badge colour for [title], tinted by the theme [primary].
///
/// The hue comes from the title, then moves part of the way toward the
/// primary hue: badges still differ from one app to the next, but stay close
/// to the palette. Saturation follows the primary too, so a muted theme gets
/// muted badges. Lightness is fixed to keep the white symbol readable.
@visibleForTesting
Color letterIconColor(String title, Color primary) {
  var hash = 0;
  for (final rune in title.runes) {
    hash = (hash * 31 + rune) & 0x7fffffff;
  }
  final seedHue = (hash % 360).toDouble();

  final theme = HSLColor.fromColor(primary);
  // A grey primary has no meaningful hue to pull toward.
  final pull = theme.saturation < 0.1 ? 0.0 : _huePull;
  final delta = (theme.hue - seedHue + 540) % 360 - 180;
  final hue = (seedHue + delta * pull) % 360;
  final saturation = (theme.saturation * 0.8).clamp(0.2, 0.5);

  return HSLColor.fromAHSL(1, hue, saturation, 0.4).toColor();
}

/// How far each badge hue moves toward the primary hue.
const _huePull = 0.6;
