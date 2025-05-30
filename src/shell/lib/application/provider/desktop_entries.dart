import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'desktop_entries.g.dart';

@Riverpod(keepAlive: true)
Future<Map<String, DesktopEntry>> installedDesktopEntries(
  Ref ref,
) async {
  final entries = await parseAllInstalledDesktopFiles();
  return entries;
}
