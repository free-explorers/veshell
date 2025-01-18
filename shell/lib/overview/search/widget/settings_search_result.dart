import 'package:flutter/material.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/provider/app_drawer.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/screen/provider/current_screen_id.dart';

/// List of applications for the given searchText
class SettingsSearchResult extends HookConsumerWidget {
  ///
  const SettingsSearchResult({required this.searchText, super.key});
  final String searchText;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktopEntries =
        ref.watch(appDrawerFilteredDesktopEntriesProvider(searchText));
    return ListView.builder(
      itemBuilder: (context, index) {
        final desktopEntry = desktopEntries.requireValue[index];
        return ListTile(
          title: Text(
            desktopEntry.entries[DesktopEntryKey.name.string] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            desktopEntry.entries[DesktopEntryKey.comment.string] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: SizedBox(
            width: 42,
            child: AspectRatio(
              aspectRatio: 1,
              child: AppIconByPath(
                path: desktopEntry.entries[DesktopEntryKey.icon.string],
              ),
            ),
          ),
          onTap: () {
            print(
              'Launch ${desktopEntry.entries[DesktopEntryKey.name.string]}',
            );
            ref
                .read(
                  overviewStateProvider(ref.read(currentScreenIdProvider))
                      .notifier,
                )
                .startEphemeralApplication(desktopEntry);
          },
          visualDensity: VisualDensity.comfortable,
          focusColor: Theme.of(context).colorScheme.primary.withAlpha(50),
          hoverColor: Theme.of(context).colorScheme.primary.withAlpha(25),
        );
      },
      itemCount: desktopEntries.maybeWhen(
        data: (desktopEntries) => desktopEntries.length,
        orElse: () => 0,
      ),
    );
  }
}
