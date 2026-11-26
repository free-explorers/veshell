import 'dart:io';

import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/model/steam_game.dart';
import 'package:shell/application/provider/icon_file_from_query.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/window/model/resume_context.serializable.dart';

part 'window_art.g.dart';

/// Width over height of [WindowArt.portrait]: Steam's library capsule.
const double portraitArtAspectRatio = 2 / 3;

/// Width over height of [WindowArt.landscape]: Steam's header capsule.
const double landscapeArtAspectRatio = 460 / 215;

/// The art of the application a window shows: its icon wherever the window
/// is named, and the artwork and backdrop of its placeholder.
class WindowArt {
  const WindowArt({
    this.iconPath,
    this.name,
    this.backdrop,
    this.portrait,
    this.landscape,
  });

  /// An icon for `AppIconByPath`: a theme icon name or an absolute path.
  final String? iconPath;

  /// The application's name from its desktop entry, for the icon's letter
  /// fallback.
  final String? name;

  /// An image of the application, already blurred, to paint behind the
  /// placeholder.
  final File? backdrop;

  /// A cover of the application, [portraitArtAspectRatio], shown in place of
  /// its icon beside the placeholder's title.
  final File? portrait;

  /// A banner of the application, [landscapeArtAspectRatio], shown in place
  /// of its icon above the placeholder's title.
  final File? landscape;
}

/// The icon and backdrop of the application a window shows, named by its
/// [appId] and [windowClass] and by how it was last running
/// ([resumeContext]), from every source that knows the application:
/// 1. its desktop entry's icon;
/// 2. for a Steam game, which often has no desktop entry, Steam's themed icon,
///    client icon or library cache icon, the cache's cover and header as
///    artwork, and its blurred banner as backdrop.
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
  final entries = (await entry)?.entries;
  final entryIcon = entries?[DesktopEntryKey.icon.string];
  final name = entries?[DesktopEntryKey.name.string];
  if (steamAppId == null) {
    return WindowArt(iconPath: entryIcon, name: name);
  }

  final library = _steamLibraryArt(steamAppId);
  // The shortcut's themed icon, then the client icon (up to 256 px), then the
  // library cache's 32 px one.
  final steamIcon = await steamThemedIcon != null
      ? steamIconName(steamAppId)
      : (await _steamClientIcon(steamAppId))?.path ?? library.icon?.path;
  return WindowArt(
    iconPath: entryIcon ?? steamIcon,
    name: name,
    backdrop: library.heroBlur,
    portrait: library.portrait,
    landscape: library.landscape,
  );
}

List<String> _steamRoots() => steamRootsFromEnvironment(Platform.environment);

SteamLibraryArt _steamLibraryArt(String steamAppId) =>
    findSteamLibraryArt(steamAppId, _steamRoots());

Future<File?> _steamClientIcon(String steamAppId) =>
    findSteamClientIcon(steamAppId, _steamRoots());
