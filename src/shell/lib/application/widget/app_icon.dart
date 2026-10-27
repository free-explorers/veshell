import 'package:flutter_svg/flutter_svg.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/icon_file_from_query.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/application/util/icon_size.dart';
import 'package:shell/application/util/normalizing_svg_file_loader.dart';
import 'package:shell/application/widget/letter_app_icon.dart';

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
      // The normalizing loader inlines `<style>`/`class` selectors, which
      // flutter_svg ignores; without it themed icons that rely on them render
      // as a solid black square.
      return SvgPicture(NormalizingSvgFileLoader(iconFile));
    }
    // `cacheWidth` is in physical pixels; the decoded frame lives in Flutter's
    // global `ImageCache`, which outlives this widget and the provider.
    return Image.file(iconFile, cacheWidth: bucket);
  }
}

class AppIconById extends ConsumerWidget {
  const AppIconById({
    required this.id,
    super.key,
    this.fallback = const Icon(MdiIcons.helpCircle),
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
