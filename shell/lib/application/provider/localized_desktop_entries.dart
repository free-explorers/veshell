import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/desktop_entries.dart';

part 'localized_desktop_entries.g.dart';

@Riverpod(keepAlive: true)
Future<Map<String, LocalizedDesktopEntry>> localizedDesktopEntries(
  LocalizedDesktopEntriesRef ref,
) async {
  final desktopEntries =
      await ref.watch(installedDesktopEntriesProvider.future);
  return desktopEntries
      .map((key, value) => MapEntry(key, value.localize(lang: 'en')));
}

@riverpod
class LocalizedDesktopEntryForId extends _$LocalizedDesktopEntryForId {
  @override
  FutureOr<LocalizedDesktopEntry?> build(String appId) async {
    return ref.watch(
      localizedDesktopEntriesProvider.selectAsync((data) => data[appId]),
    );
  }
}
