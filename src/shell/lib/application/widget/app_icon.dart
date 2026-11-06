import 'dart:io';

import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/icon_file_from_query.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/application/provider/png_pixel_size.dart';
import 'package:shell/application/util/icon_size.dart';
import 'package:shell/application/widget/grid_fit_svg_icon.dart';
import 'package:shell/application/widget/letter_app_icon.dart';
import 'package:shell/shared/widget/shell_icon.dart';

/// Below this fraction of the icon box, a raster icon is not stretched to the
/// box but shown at its own size on a plate (see [_PlatedRasterIcon]).
const _plateThreshold = 0.7;

class AppIconByPath extends StatelessWidget {
  const AppIconByPath({required this.path, this.title, super.key});

  final String? path;

  /// The application name used to draw the letter fallback.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final label = title?.trim();
    if (path == null || path!.isEmpty) {
      return label == null || label.isEmpty
          ? const SizedBox()
          : LetterAppIcon(title: label);
    }

    return LayoutBuilder(
      builder: (context, constraints) => Consumer(
        builder: (context, ref, _) => _buildIcon(
          context,
          ref,
          path!,
          label,
          constraints.biggest.shortestSide,
        ),
      ),
    );
  }

  Widget _buildIcon(
    BuildContext context,
    WidgetRef ref,
    String path,
    String? label,
    double logicalSize,
  ) {
    if (logicalSize <= 0) return const SizedBox();

    // Snap to a physical-pixel bucket so the resolution and pixel caches stay
    // bounded, and decode at the device pixel ratio so icons are crisp on
    // HiDPI displays.
    final bucket = iconPhysicalBucket(
      logicalSize,
      MediaQuery.devicePixelRatioOf(context),
    );

    final icon = ref.watch(
      iconFileFromQueryProvider(
        IconQuery(name: path, size: bucket, extensions: const ['svg', 'png']),
      ),
    );
    final iconFile = icon.value;
    if (iconFile == null) {
      // A pending lookup is not a missing icon: show nothing until the theme
      // has answered, then the letter fallback if it found no file.
      if (icon.isLoading) return const SizedBox();
      return label == null || label.isEmpty
          ? const SizedBox()
          : LetterAppIcon(title: label);
    }

    // Let the image widgets own their decoded frames. In particular, a
    // RawImage using a provider-owned ui.Image can lose its handle when the
    // provider is rebuilt during icon-theme initialization at session start.
    if (iconFile.path.endsWith('.svg')) {
      // Grid-fitted, so the icon stays crisp at fractional scales; it falls
      // back to flutter_svg (through the CSS-normalizing loader) for what the
      // fitter cannot draw.
      return GridFitSvgIcon(file: iconFile, size: logicalSize);
    }
    // `cacheWidth` is in physical pixels; the decoded frame lives in Flutter's
    // global `ImageCache`, which outlives this widget and the provider. A PNG
    // cannot be grid-fitted: it is decoded at the next bucket up and scaled
    // down with mipmaps (`Image`'s default medium filter quality), the
    // sharpest a fixed-size image gets at a fractional scale.
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final pixelSize = ref.watch(pngPixelSizeProvider(iconFile.path));
    if (pixelSize != null &&
        pixelSize.longestSide <
            logicalSize * devicePixelRatio * _plateThreshold) {
      return _PlatedRasterIcon(
        file: iconFile,
        size: pixelSize / devicePixelRatio,
        label: label,
      );
    }
    // `cacheWidth` never upscales, so a PNG a little smaller than the bucket
    // keeps its own size; `contain` brings it up to the icon box like every
    // SVG. Much smaller ones are plated above instead: stretched, they blur.
    return Image.file(iconFile, cacheWidth: bucket, fit: BoxFit.contain);
  }
}

class AppIconById extends ConsumerWidget {
  const AppIconById({
    required this.id,
    super.key,
    this.fallback = const ShellIcon(MdiIcons.helpCircle),
  });

  final String? id;

  /// Shown while the desktop entry is unknown, or when it names no title.
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (id == null) {
      return fallback;
    }

    return ref
        .watch(localizedDesktopEntryForIdProvider(id!))
        .maybeWhen(
          data: (entry) {
            if (entry == null) {
              return fallback;
            }
            final title = entry.entries[DesktopEntryKey.name.string];
            final iconPath = entry.entries[DesktopEntryKey.icon.string];
            if (title == null || title.trim().isEmpty) {
              return fallback;
            }
            return AppIconByPath(path: iconPath, title: title);
          },
          orElse: () => fallback,
        );
  }
}

/// A raster icon too small for its box, at its own pixel size on a rounded
/// plate that fills the box: stretching it would blur it (the 48 px legacy
/// theme icons, `/usr/share/pixmaps`), and painting it bare would leave it
/// small among full-size icons. The plate matches [LetterAppIcon]'s shape.
class _PlatedRasterIcon extends StatelessWidget {
  const _PlatedRasterIcon({
    required this.file,
    required this.size,
    required this.label,
  });

  final File file;

  /// The icon's own size, in logical pixels.
  final Size size;

  final String? label;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = constraints.biggest.shortestSide;
        return Semantics(
          label: label,
          image: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(boxSize * 0.22),
            ),
            child: Center(
              child: Image.file(file, width: size.width, height: size.height),
            ),
          ),
        );
      },
    );
  }
}
