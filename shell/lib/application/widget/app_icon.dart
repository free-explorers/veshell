import 'package:flutter/material.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jovial_svg/jovial_svg.dart';
import 'package:shell/application/provider/desktop_entries.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/xdg_toplevel_state.dart';

class AppIconByPath extends StatelessWidget {
  const AppIconByPath({
    required this.path,
    super.key,
  });

  final String? path;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, WidgetRef ref, __) {
        if (path == null) {
          return const SizedBox();
        }
        return _buildIcon(ref, path!);
      },
    );
  }

  Widget _buildIcon(WidgetRef ref, String icon) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final asyncValue = ref.watch(
          iconProvider(
            IconQuery(
              name: icon,
              size: constraints.biggest.shortestSide.floor(),
              extensions: const ['svg', 'png'],
            ),
          ),
        );

        if (!asyncValue.hasValue) {
          return const SizedBox();
        }
        final file = asyncValue.value;

        if (file == null) {
          return const SizedBox();
        }

        if (file.path.endsWith('.svg')) {
          return Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              return ref
                  .watch(fileToScalableImageProvider(file.absolute.path))
                  .when(
                data: (ScalableImage scalableImage) {
                  return SizedBox.expand(
                    child: ScalableImageWidget(
                      si: scalableImage,
                    ),
                  );
                },
                error: (Object error, StackTrace stackTrace) {
                  return const SizedBox();
                },
                loading: () {
                  return const SizedBox();
                },
              );
            },
          );
        }

        return Image.file(
          file,
          filterQuality: FilterQuality.medium,
          fit: BoxFit.contain,
        );
      },
    );
  }
}

class AppIconById extends ConsumerWidget {
  const AppIconById({
    required this.id,
    super.key,
  });

  final String? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(localizedDesktopEntriesProvider).maybeWhen(
          data: (Map<String, LocalizedDesktopEntry> desktopEntries) {
            if (id == null) {
              // TODO(roscale): Return a default icon for unknown apps.
              return const SizedBox();
            }
            final entry = desktopEntries[id];
            if (entry == null) {
              // TODO(roscale): Return a default icon for unknown apps.
              return const SizedBox();
            }
            final iconPath = entry.entries[DesktopEntryKey.icon.string];
            if (iconPath == null) {
              // TODO(roscale): Return a default icon for unknown apps.
              return const SizedBox();
            }
            return AppIconByPath(path: iconPath);
          },
          // TODO(roscale): Return a default icon for unknown apps.
          orElse: () => const SizedBox(),
        );
  }
}

class AppIconByViewId extends ConsumerWidget {
  const AppIconByViewId({
    required this.surfaceId,
    super.key,
  });

  final SurfaceId surfaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appId =
        ref.watch(xdgToplevelStateProvider(surfaceId).select((v) => v.appId));
    // TODO: Return an default icon for unknown apps.
    return AppIconById(id: appId);
  }
}
