import 'dart:io';

import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/model/steam_game.dart';
import 'package:shell/application/provider/icon_file_from_query.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/window/model/resume_context.serializable.dart';

part 'window_art.g.dart';

/// The art a window's placeholder shows while the application is not running.
class WindowArt {
  const WindowArt({this.iconPath, this.backdrop});

  /// An icon for `AppIconByPath`: a theme icon name or an absolute path.
  final String? iconPath;

  /// An image of the application, already blurred, to paint behind the
  /// placeholder.
  final File? backdrop;
}

/// The icon and backdrop of the application a window shows, named by its
/// [appId] and [windowClass] and by how it was last running
/// ([resumeContext]), from every source that knows the application:
/// 1. its desktop entry's icon;
/// 2. for a Steam game, which often has no desktop entry, Steam's themed icon
///    or its library cache's, and the cache's blurred banner as backdrop.
///
/// Keyed by the fields naming the application only, not the whole window: a
/// title change must not look the files up again. Not kept alive: Steam fills
/// its cache while its library is browsed, so a placeholder shown again looks
/// again.
@riverpod
Future<WindowArt> windowArt(
  Ref ref, {
  required String appId,
  String? windowClass,
  ResumeContext? resumeContext,
}) {
  final steamAppId =
      resumeContext?.steamAppId ??
      steamAppIdOfWindow(appId) ??
      steamAppIdOfWindow(windowClass);

  // Every `ref` use happens before the first suspension point (see
  // `LocalizedDesktopEntryForId`).
  final entry = ref.watch(localizedDesktopEntryForIdProvider(appId).future);
  final steamThemedIcon = steamAppId == null
      ? null
      : ref.watch(
          iconFileFromQueryProvider(
            IconQuery(
              name: steamIconName(steamAppId),
              size: 48,
              extensions: const ['png', 'svg'],
            ),
          ).future,
        );
  return _resolve(entry, steamAppId, steamThemedIcon);
}

Future<WindowArt> _resolve(
  Future<LocalizedDesktopEntry?> entry,
  String? steamAppId,
  Future<File?>? steamThemedIcon,
) async {
  final entryIcon = (await entry)?.entries[DesktopEntryKey.icon.string];
  if (steamAppId == null) {
    return WindowArt(iconPath: entryIcon);
  }

  final library = _steamLibraryArt(steamAppId);
  final steamIcon = await steamThemedIcon != null
      ? steamIconName(steamAppId)
      : library.icon?.path;
  return WindowArt(
    iconPath: entryIcon ?? steamIcon,
    backdrop: library.heroBlur,
  );
}

SteamLibraryArt _steamLibraryArt(String steamAppId) {
  final environment = Platform.environment;
  final home = environment['HOME'];
  if (home == null) return const SteamLibraryArt();
  return findSteamLibraryArt(
    steamAppId,
    steamRoots(home: home, dataHome: environment['XDG_DATA_HOME']),
  );
}
