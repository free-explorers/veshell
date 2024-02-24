import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';

part 'app_drawer_desktop_entries.g.dart';

@Riverpod(keepAlive: true)
Future<Iterable<LocalizedDesktopEntry>> appDrawerDesktopEntries(
  AppDrawerDesktopEntriesRef ref,
) async {
  final localizedDesktopEntries =
      await ref.watch(localizedDesktopEntriesProvider.future);
  return localizedDesktopEntries.values
      .where((element) => !element.desktopEntry.isHidden());
}
