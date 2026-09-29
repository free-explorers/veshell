import 'dart:io';

import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';

/// The album art of the active MPRIS track.
///
/// MPRIS advertises art as a `file://` or `http(s)://` URL; anything else (or a
/// broken image) falls back to a neutral music glyph.
class MprisArtwork extends StatelessWidget {
  const MprisArtwork({required this.url, this.size = 72, super.key});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: _image(context),
        ),
      ),
    );
  }

  Widget _image(BuildContext context) {
    final url = this.url;
    if (url == null || url.isEmpty) {
      return _fallback(context);
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return _fallback(context);
    }
    if (uri.scheme == 'file') {
      return Image.file(
        File.fromUri(uri),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(context),
      );
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(context),
      );
    }
    if (uri.scheme.isEmpty) {
      return Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(context),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    return Center(
      child: Icon(
        MdiIcons.musicNote,
        size: size * 0.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
