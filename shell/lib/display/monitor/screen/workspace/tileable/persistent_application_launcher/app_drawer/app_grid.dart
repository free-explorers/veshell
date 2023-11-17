import 'package:flutter/material.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:veshell/display/monitor/screen/workspace/tileable/persistent_application_launcher/app_drawer/app_drawer.provider.dart';
import 'package:veshell/manager/application/app_icon.dart';
import 'package:veshell/shared/util/app_launch.dart';

class AppGrid extends ConsumerStatefulWidget {
  const AppGrid({super.key});

  @override
  ConsumerState<AppGrid> createState() => _AppGridState();
}

class _AppGridState extends ConsumerState<AppGrid> {
  @override
  Widget build(BuildContext context) {
    final widgets = ref.watch(appEntryWidgetProvider);

    return Material(
      color: Colors.transparent,
      child: GridView.builder(
        itemCount: widgets.length,
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 90,
          childAspectRatio: 0.65,
        ),
        itemBuilder: (BuildContext context, int index) => widgets[index],
      ),
    );
  }
}

class AppEntry extends ConsumerWidget {
  const AppEntry({
    required this.desktopEntry,
    super.key,
  });
  final LocalizedDesktopEntry desktopEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        if (await launchDesktopEntry(desktopEntry.desktopEntry)) {
          ref.read(appDrawerVisibleProvider.notifier).state = false;
        }
      },
      child: Column(
        children: [
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return ConstrainedBox(
                constraints: constraints.copyWith(
                  minHeight: constraints.maxWidth,
                  maxHeight: constraints.maxWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: AppIconByPath(
                    path: desktopEntry.entries[DesktopEntryKey.icon.string],
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: Text(
              desktopEntry.entries[DesktopEntryKey.name.string] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
