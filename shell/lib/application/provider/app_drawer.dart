import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/desktop_entries.dart';

part 'app_drawer.g.dart';

@Riverpod(keepAlive: true)
class AppDrawerFilter extends _$AppDrawerFilter {
  // Make it public. Was protected in the superclass.
  @override
  set state(String value) {
    super.state = value;
  }

  @override
  String build() {
    return '';
  }
}

@Riverpod(keepAlive: true)
Future<List<LocalizedDesktopEntry>> appDrawerFilteredDesktopEntries(
  AppDrawerFilteredDesktopEntriesRef ref,
) async {
  final filter = ref.watch(appDrawerFilterProvider);
  final desktopEntries =
      await ref.watch(appDrawerDesktopEntriesProvider.future);

  final filtered = <LocalizedDesktopEntry>[];
  final desktopEntriesSet = Set<LocalizedDesktopEntry>.from(desktopEntries);

  int byNames(LocalizedDesktopEntry a, LocalizedDesktopEntry b) {
    final aName = a.entries[DesktopEntryKey.name.string]!;
    final bName = b.entries[DesktopEntryKey.name.string]!;
    return aName.toLowerCase().compareTo(bName.toLowerCase());
  }

  final nameMatched = desktopEntriesSet.where((d) {
    final name = d.entries[DesktopEntryKey.name.string]!.toLowerCase();
    return name.startsWith(filter);
  }).toList()
    ..sort(byNames);

  filtered.addAll(nameMatched);
  desktopEntriesSet.removeAll(nameMatched);

  final namePartsMatched = desktopEntriesSet.where((d) {
    final name = d.entries[DesktopEntryKey.name.string]!.toLowerCase();
    final nameParts = name.split(' ');
    return nameParts.any((part) => part.startsWith(filter));
  }).toList()
    ..sort(byNames);

  filtered.addAll(namePartsMatched);
  desktopEntriesSet.removeAll(namePartsMatched);

  final keywordsMatched = desktopEntriesSet.where((d) {
    final keywords =
        d.entries[DesktopEntryKey.keywords.string]?.getStringList();
    if (keywords == null) {
      return false;
    }
    for (final kw in keywords) {
      kw.toLowerCase();
    }
    return keywords.any((kw) => kw.startsWith(filter));
  }).toList()
    ..sort(byNames);

  filtered.addAll(keywordsMatched);

  return filtered;
}
