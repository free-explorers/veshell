import 'package:flutter/material.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/manager/application/app_drawer.provider.dart';
import 'package:shell/manager/application/app_icon.dart';

/// Desktop entry selected callback
typedef DesktopEntrySelectedCallback = void Function(
  LocalizedDesktopEntry desktopEntry,
);

/// Application grid
class AppGrid extends HookConsumerWidget {
  /// Const constructor
  const AppGrid({required this.onSelect, super.key});

  /// Desktop entry selected callback
  final DesktopEntrySelectedCallback onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktopEntries = ref.watch(appDrawerFilteredDesktopEntriesProvider);
    final widgets = desktopEntries.maybeWhen(
      skipLoadingOnReload: true,
      data: (List<LocalizedDesktopEntry> desktopEntries) => desktopEntries
          .map(
            (desktopEntry) => AppEntry(
              desktopEntry: desktopEntry,
              onLaunch: onSelect,
            ),
          )
          .toList(),
      orElse: () => <Widget>[],
    );
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

/// Application entry
class AppEntry extends ConsumerWidget {
  /// Const constructor
  const AppEntry({
    required this.desktopEntry,
    required this.onLaunch,
    super.key,
  });

  /// Desktop entry
  final LocalizedDesktopEntry desktopEntry;

  /// Desktop entry selected callback
  final DesktopEntrySelectedCallback onLaunch;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        //await launchDesktopEntry(desktopEntry.desktopEntry)
        onLaunch(desktopEntry);
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
