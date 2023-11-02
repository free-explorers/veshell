import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/ui/common/state/app_drawer.dart';
import 'package:zenith/ui/common/app_icon.dart';
import 'package:zenith/ui/mobile/state/app_drawer_state.dart';
import 'package:zenith/util/app_launch.dart';

part '../../../generated/ui/mobile/app_drawer/app_grid.g.dart';

@Riverpod(keepAlive: true)
Future<List<AppEntry>> _appWidgets(_AppWidgetsRef ref) async {
  final desktopEntries = await ref.watch(appDrawerFilteredDesktopEntriesProvider.future);
  return desktopEntries.map((desktopEntry) => AppEntry(desktopEntry: desktopEntry)).toList();
}

class AppGrid extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const AppGrid({super.key, required this.scrollController});

  @override
  ConsumerState<AppGrid> createState() => _AppGridState();
}

class _AppGridState extends ConsumerState<AppGrid> {
  @override
  Widget build(BuildContext context) {
    final widgets = ref.watch(_appWidgetsProvider).maybeWhen(
          data: (widgets) => widgets,
          orElse: () => [],
          skipLoadingOnReload: true,
        );

    bool dragging = ref.watch(appDrawerNotifierProvider.select((value) => value.dragging));

    return GridView.builder(
      controller: widget.scrollController,
      physics: dragging ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
      itemCount: widgets.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 100),
      itemBuilder: (BuildContext context, int index) => widgets[index],
    );
  }
}

class AppEntry extends ConsumerWidget {
  final LocalizedDesktopEntry desktopEntry;

  const AppEntry({
    Key? key,
    required this.desktopEntry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        if (await launchDesktopEntry(desktopEntry.desktopEntry)) {
          ref.read(appDrawerNotifierProvider.notifier).update((state) => state.copyWith(closePanel: Object()));
        }
      },
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: AppIconByPath(
                path: desktopEntry.entries[DesktopEntryKey.icon.string],
              ),
            ),
          ),
          Text(
            desktopEntry.entries[DesktopEntryKey.name.string] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
