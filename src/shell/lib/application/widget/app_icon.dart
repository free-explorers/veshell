import 'package:flutter_svg/flutter_svg.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/icon_file_from_query.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';

class AppIconByPath extends StatelessWidget {
  const AppIconByPath({required this.path, super.key, this.constrainedSize});

  final String? path;
  final int? constrainedSize;

  @override
  Widget build(BuildContext context) {
    if (path == null) return const SizedBox();

    if (constrainedSize != null) {
      return Consumer(
        builder: (context, ref, _) => _buildIcon(ref, path!, constrainedSize!),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => Consumer(
        builder: (context, ref, _) =>
            _buildIcon(ref, path!, constraints.biggest.shortestSide.floor()),
      ),
    );
  }

  Widget _buildIcon(WidgetRef ref, String path, int size) {
    if (size <= 0) return const SizedBox();

    final iconFile = ref
        .watch(
          iconFileFromQueryProvider(
            IconQuery(name: path, size: size, extensions: const ['svg', 'png']),
          ),
        )
        .value;
    if (iconFile == null) return const SizedBox();

    // Let the image widgets own their decoded frames. In particular, a
    // RawImage using a provider-owned ui.Image can lose its handle when the
    // provider is rebuilt during icon-theme initialization at session start.
    if (iconFile.path.endsWith('.svg')) {
      return SvgPicture.file(iconFile);
    }
    return Image.file(iconFile, cacheWidth: size);
  }
}

class AppIconById extends ConsumerWidget {
  const AppIconById({
    required this.id,
    super.key,
    this.constrainedSize,
    this.fallback = const Icon(MdiIcons.helpCircle),
  });

  final String? id;

  final int? constrainedSize;

  /// Shown while the desktop entry is unknown, or when it names no icon.
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
            final iconPath = entry.entries[DesktopEntryKey.icon.string];
            if (iconPath == null) {
              return fallback;
            }
            return AppIconByPath(
              path: iconPath,
              constrainedSize: constrainedSize,
            );
          },
          orElse: () => fallback,
        );
  }
}
