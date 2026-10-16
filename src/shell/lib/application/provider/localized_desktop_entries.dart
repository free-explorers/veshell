import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:path/path.dart' as path;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/model/application_identity.dart';
import 'package:shell/application/provider/desktop_entries.dart';
import 'package:shell/l10n/l10n.dart';

part 'localized_desktop_entries.g.dart';

@Riverpod(keepAlive: true)
Future<Map<String, LocalizedDesktopEntry>> localizedDesktopEntries(
  Ref ref,
) async {
  final locales = ref.watch(systemLocalesProvider);
  final locale = locales.isEmpty ? null : locales.first;
  final desktopEntries = await ref.watch(
    installedDesktopEntriesProvider.future,
  );
  return desktopEntries.map(
    (key, value) => MapEntry(
      key,
      value.localize(
        lang: locale?.languageCode ?? 'en',
        country: locale?.countryCode,
        modifier: switch (locale?.scriptCode) {
          'Latn' => 'latin',
          'Cyrl' => 'cyrillic',
          _ => null,
        },
      ),
    ),
  );
}

@riverpod
class LocalizedDesktopEntryForId extends _$LocalizedDesktopEntryForId {
  @override
  Future<LocalizedDesktopEntry?> build(String appId) {
    // Every `ref` use must happen before the first suspension point. Once this
    // (auto-dispose) provider is rebuilt or disposed while an async build is
    // pending, Riverpod rejects any later `Ref` access, so the resolution runs
    // in a separate function over the already-watched futures.
    final binaryToAppId = ref.watch(binaryToAppIdProvider.future);
    final desktopEntries = ref.watch(localizedDesktopEntriesProvider.future);
    return _resolve(appId, binaryToAppId, desktopEntries);
  }

  Future<LocalizedDesktopEntry?> _resolve(
    String appId,
    Future<Map<String, String?>> binaryToAppId,
    Future<Map<String, LocalizedDesktopEntry>> desktopEntries,
  ) async {
    // Shared with the matcher's identity comparison so both resolve an id the
    // same way. See `resolveLocalizedDesktopEntry`.
    return resolveLocalizedDesktopEntry(
      appId: appId,
      entries: await desktopEntries,
      binaryToAppId: await binaryToAppId,
    );
  }
}

@riverpod
class BinaryToAppId extends _$BinaryToAppId {
  @override
  FutureOr<Map<String, String?>> build() async {
    final desktopEntries = await ref.watch(
      localizedDesktopEntriesProvider.future,
    );
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
