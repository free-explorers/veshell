import 'dart:io';

import 'package:path/path.dart' as p;

/// Steam games: their identity in window ids and desktop entries, and the art
/// Steam caches for them.
///
/// A game Steam runs through Proton has no desktop entry of its own: its X11
/// class is `steam_app_<id>`. Steam only writes an entry when asked to create
/// a shortcut, and that entry starts the game through its URI
/// (`Exec=steam steam://rungameid/<id>`, `Icon=steam_icon_<id>`).

final _windowIdPattern = RegExp(r'^steam_app_(\d+)$');

/// The Steam app id in a Proton window's app id or class (`steam_app_<id>`),
/// or null for any other window.
String? steamAppIdOfWindow(String? windowId) {
  if (windowId == null) return null;
  return _windowIdPattern.firstMatch(windowId.trim().toLowerCase())?.group(1);
}

/// Whether the desktop entry command [exec] starts the Steam game
/// [steamAppId] through its URI.
///
/// The id must end there: `rungameid/12` does not start game `123`.
bool launchesSteamGame(String? exec, String steamAppId) {
  if (exec == null) return false;
  return RegExp(
    'steam://rungameid/${RegExp.escape(steamAppId)}(?![0-9])',
  ).hasMatch(exec);
}

/// The icon theme name Steam installs a game's icon under (in `hicolor`) when
/// it creates a shortcut for it.
String steamIconName(String steamAppId) => 'steam_icon_$steamAppId';

/// The directories Steam can be installed in, most common first: the native
/// client's `~/.steam/steam` link and its data directory, then Flatpak's.
List<String> steamRoots({required String home, String? dataHome}) {
  final data = dataHome == null || dataHome.isEmpty
      ? p.join(home, '.local', 'share')
      : dataHome;
  return [
    p.join(home, '.steam', 'steam'),
    p.join(data, 'Steam'),
    p.join(
      home,
      '.var',
      'app',
      'com.valvesoftware.Steam',
      '.local',
      'share',
      'Steam',
    ),
  ];
}

/// The art Steam caches for a game in its library cache.
class SteamLibraryArt {
  const SteamLibraryArt({this.icon, this.heroBlur});

  /// The game's small icon (about 32 px).
  final File? icon;

  /// A small, already blurred copy of the wide banner over the game's library
  /// page, which Steam shows while the banner loads.
  final File? heroBlur;

  bool get isEmpty => icon == null && heroBlur == null;
}

/// A file name in the hash-named library cache layout: the icon is stored
/// under the SHA-1 of its content.
final _hashedImagePattern = RegExp(r'^[0-9a-f]{40}\.jpg$');

/// Finds the cached art of [steamAppId] in the first of [roots] that has any.
///
/// Steam has stored its library cache in two layouts:
/// - per game directory: `librarycache/<id>/library_hero_blur.jpg`, the icon
///   as `librarycache/<id>/<sha1>.jpg`;
/// - flat (older clients): `librarycache/<id>_library_hero_blur.jpg` and
///   `librarycache/<id>_icon.jpg`.
///
/// Steam fills the cache for the games its library has shown, so a game can
/// have none of it.
SteamLibraryArt findSteamLibraryArt(String steamAppId, Iterable<String> roots) {
  for (final root in roots) {
    final cache = p.join(root, 'appcache', 'librarycache');
    final gameDirectory = Directory(p.join(cache, steamAppId));

    File? icon;
    File? heroBlur;
    if (gameDirectory.existsSync()) {
      final blur = File(p.join(gameDirectory.path, 'library_hero_blur.jpg'));
      if (blur.existsSync()) heroBlur = blur;
      try {
        for (final file in gameDirectory.listSync(followLinks: false)) {
          if (file is File &&
              _hashedImagePattern.hasMatch(p.basename(file.path))) {
            icon = file;
            break;
          }
        }
      } on FileSystemException {
        // An unreadable directory has no usable art.
      }
    }
    final flatIcon = File(p.join(cache, '${steamAppId}_icon.jpg'));
    if (icon == null && flatIcon.existsSync()) icon = flatIcon;
    final flatBlur = File(p.join(cache, '${steamAppId}_library_hero_blur.jpg'));
    if (heroBlur == null && flatBlur.existsSync()) heroBlur = flatBlur;

    final art = SteamLibraryArt(icon: icon, heroBlur: heroBlur);
    if (!art.isEmpty) return art;
  }
  return const SteamLibraryArt();
}
