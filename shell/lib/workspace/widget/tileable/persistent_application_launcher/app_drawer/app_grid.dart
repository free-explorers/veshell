import 'package:flutter/material.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/provider/app_drawer.dart';
import 'package:shell/application/widget/app_icon.dart';

/// Desktop entry selected callback
typedef DesktopEntrySelectedCallback = void Function(
  LocalizedDesktopEntry desktopEntry,
);

/// Application grid
class AppGrid extends HookConsumerWidget {
  /// Const constructor
  const AppGrid({required this.searchText, required this.onSelect, super.key});

  final String searchText;

  /// Desktop entry selected callback
  final DesktopEntrySelectedCallback onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktopEntries =
        ref.watch(appDrawerFilteredDesktopEntriesProvider(searchText));
    final widgets = desktopEntries.maybeWhen(
      skipLoadingOnReload: true,
      data: (List<LocalizedDesktopEntry> desktopEntries) => desktopEntries
          .map(
            (desktopEntry) => AppEntry(
              key: ValueKey(desktopEntry.desktopEntry.id),
              desktopEntry: desktopEntry,
              onLaunch: onSelect,
            ),
          )
          .toList(),
      orElse: () => <Widget>[],
    );
    return GridView.builder(
      itemCount: widgets.length,
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        childAspectRatio: 0.68,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (BuildContext context, int index) => widgets[index],
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
      borderRadius: BorderRadius.circular(24),
      onTap: () async {
        onLaunch(desktopEntry);
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: AspectRatio(
                aspectRatio: 1,
                child: AppIconByPath(
                  path: desktopEntry.entries[DesktopEntryKey.icon.string],
                ),
              ),
            ),
            Text(
              desktopEntry.entries[DesktopEntryKey.name.string] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
