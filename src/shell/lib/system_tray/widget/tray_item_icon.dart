import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/util/icon_size.dart';
import 'package:shell/application/widget/grid_fit_svg_icon.dart';
import 'package:shell/shared/widget/shell_icon.dart';
import 'package:shell/system_tray/model/tray_item.dart';
import 'package:shell/system_tray/model/tray_properties.dart';
import 'package:shell/system_tray/provider/tray_icon_file.dart';

/// A tray item's icon at [size] logical pixels, in its current status: the
/// named icon when it resolves, else the pixmap the item sent, else a
/// generic glyph.
class TrayItemIcon extends ConsumerWidget {
  const TrayItemIcon({required this.item, required this.size, super.key});

  final TrayItem item;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = item.currentIcon;
    final bucket = iconPhysicalBucket(
      size,
      MediaQuery.devicePixelRatioOf(context),
    );
    final pixmap = bestTrayPixmap(icon.pixmaps, bucket);
    final fallback = pixmap != null
        ? TrayPixmapIcon(pixmap: pixmap, size: size)
        : ShellIcon(MdiIcons.applicationOutline, size: size);
    return SizedBox.square(
      dimension: size,
      child: icon.name.isEmpty
          ? fallback
          : TrayNamedIcon(
              name: icon.name,
              themePath: item.iconThemePath,
              size: size,
              fallback: fallback,
            ),
    );
  }
}

/// The icon [name], looked up in [themePath] and the icon theme, or
/// [fallback] when it does not resolve.
class TrayNamedIcon extends ConsumerWidget {
  const TrayNamedIcon({
    required this.name,
    required this.themePath,
    required this.size,
    required this.fallback,
    super.key,
  });

  final String name;
  final String themePath;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bucket = iconPhysicalBucket(
      size,
      MediaQuery.devicePixelRatioOf(context),
    );
    final file = ref.watch(trayIconFileProvider(name, themePath, bucket)).value;
    if (file == null) return fallback;
    if (file.path.endsWith('.svg')) {
      return GridFitSvgIcon(file: file, size: size);
    }
    return Image.file(
      file,
      cacheWidth: bucket,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// A pixmap the item sent, scaled to [size] logical pixels.
class TrayPixmapIcon extends StatelessWidget {
  const TrayPixmapIcon({required this.pixmap, required this.size, super.key});

  final TrayPixmap pixmap;
  final double size;

  @override
  Widget build(BuildContext context) => Image(
    image: TrayPixmapImage(pixmap),
    width: size,
    height: size,
    fit: BoxFit.contain,
  );
}

/// Decodes a [TrayPixmap]'s raw RGBA pixels. Keyed by the pixels, so equal
/// pixmaps share one decoded image in Flutter's image cache.
@immutable
class TrayPixmapImage extends ImageProvider<TrayPixmapImage> {
  const TrayPixmapImage(this.pixmap);

  final TrayPixmap pixmap;

  @override
  Future<TrayPixmapImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    TrayPixmapImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_decode(key.pixmap));

  static Future<ImageInfo> _decode(TrayPixmap pixmap) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(pixmap.rgba);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: pixmap.width,
      height: pixmap.height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    try {
      final frame = await codec.getNextFrame();
      return ImageInfo(image: frame.image);
    } finally {
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is TrayPixmapImage && other.pixmap == pixmap;

  @override
  int get hashCode => pixmap.hashCode;
}
