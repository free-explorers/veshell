import 'package:flutter/material.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jovial_svg/jovial_svg.dart';
import 'package:shell/manager/application/desktop_entries.provider.dart';
import 'package:shell/shared/wayland/xdg_toplevel/xdg_toplevel.provider.dart';

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
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(localizedDesktopEntriesProvider).maybeWhen(
          data: (Map<String, LocalizedDesktopEntry> desktopEntries) {
            final entry = desktopEntries[id];
            if (entry == null) {
              return const SizedBox();
            }
            final iconPath = entry.entries[DesktopEntryKey.icon.string];
            if (iconPath == null) {
              return const SizedBox();
            }
            return AppIconByPath(path: iconPath);
          },
          orElse: () => const SizedBox(),
        );
  }
}

class AppIconByViewId extends ConsumerWidget {
  const AppIconByViewId({
    required this.surfaceId,
    super.key,
  });
  final int surfaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appId =
        ref.watch(xdgToplevelStatesProvider(surfaceId).select((v) => v.appId));
    return AppIconById(id: appId);
  }
}
