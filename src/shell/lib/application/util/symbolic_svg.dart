import 'package:path/path.dart' as p;

/// Whether the SVG icon at [path], whose document is [svg], is a symbolic
/// (monochrome) icon meant to be drawn in the foreground colour of the
/// surface it sits on rather than in its own colours.
///
/// Two conventions mark one:
/// - freedesktop/GTK: the file is named `*-symbolic.svg`. Its stock fill
///   (Adwaita's `#2e3436`) is a placeholder GTK replaces when drawing.
/// - KDE: the geometry is filled with `currentColor` under the
///   `ColorScheme-Text` class, whose stylesheet colour (Breeze's `#232629`)
///   Plasma replaces when drawing.
///
/// Drawn as they are, both are dark grey, invisible on a dark surface.
bool isSymbolicSvg(String path, String svg) {
  if (p.basenameWithoutExtension(path).endsWith('-symbolic')) return true;
  return svg.contains('ColorScheme-Text') &&
      svg.toLowerCase().contains('currentcolor');
}
