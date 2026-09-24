import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:path/path.dart' as path;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/desktop_entries.dart';

part 'localized_desktop_entries.g.dart';

@Riverpod(keepAlive: true)
Future<Map<String, LocalizedDesktopEntry>> localizedDesktopEntries(
  Ref ref,
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
    final binaryToAppId = await ref.watch(binaryToAppIdProvider.future);
    return ref.watch(
      localizedDesktopEntriesProvider.selectAsync((data) {
        final direct = data[appId] ?? data[binaryToAppId[appId]];
        if (direct != null) return direct;
        // Clients often report an `appId`/`WM_CLASS` that matches the desktop
        // entry's `StartupWMClass` rather than its file id or binary name
        // (e.g. an Electron app reporting `hermes` for `hermes-desktop.desktop`
        // whose `StartupWMClass=Hermes`). The comparison is case-insensitive:
        // the class the toolkit reports is not case-stable.
        final normalized = appId.toLowerCase();
        for (final entry in data.values) {
          final wmClass = entry.entries[DesktopEntryKey.startupWmClass.string];
          if (wmClass != null && wmClass.toLowerCase() == normalized) {
            return entry;
          }
        }
        return null;
      }),
    );
  }
}

@riverpod
class BinaryToAppId extends _$BinaryToAppId {
  @override
  FutureOr<Map<String, String?>> build() async {
    final desktopEntries =
        await ref.watch(localizedDesktopEntriesProvider.future);
    // extract the binary name of and exec string
    return desktopEntries.map(
      (key, value) => MapEntry(
        path.basename(
          (value.entries[DesktopEntryKey.exec.string] ??
                      value.entries[DesktopEntryKey.tryExec.string])
                  ?.split(' ')
                  .first ??
              key,
        ),
        key,
      ),
    );
  }
}
