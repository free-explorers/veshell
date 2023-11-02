import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:jovial_svg/jovial_svg.dart';
import 'package:zenith/ui/common/state/desktop_entries.dart';
import 'package:zenith/ui/common/state/xdg_toplevel_state.dart';

class AppIconByPath extends StatelessWidget {
  final String? path;

  const AppIconByPath({
    Key? key,
    required this.path,
  }) : super(key: key);

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
        AsyncValue<File?> asyncValue = ref.watch(iconProvider(IconQuery(
          name: icon,
          size: constraints.biggest.shortestSide.floor(),
          extensions: const ['svg', 'png'],
        )));

        if (!asyncValue.hasValue) {
          return const SizedBox();
        }
        File? file = asyncValue.value;

        if (file == null) {
          return const SizedBox();
        }

        if (file.path.endsWith('.svg')) {
          return Consumer(builder: (BuildContext context, WidgetRef ref, Widget? child) {
            return ref.watch(fileToScalableImageProvider(file.absolute.path)).when(
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
          });
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
  final String id;

  const AppIconById({
    super.key,
    required this.id,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(localizedDesktopEntriesProvider).maybeWhen(
          data: (Map<String, LocalizedDesktopEntry> desktopEntries) {
            LocalizedDesktopEntry? entry = desktopEntries[id];
            if (entry == null) {
              return const SizedBox();
            }
            String? iconPath = entry.entries[DesktopEntryKey.icon.string];
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
  final int viewId;

  const AppIconByViewId({
    super.key,
    required this.viewId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String appId = ref.watch(xdgToplevelStatesProvider(viewId).select((v) => v.appId));
    return AppIconById(id: appId);
  }
}
