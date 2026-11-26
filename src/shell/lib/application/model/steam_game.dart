import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  const SteamLibraryArt({
    this.icon,
    this.heroBlur,
    this.portrait,
    this.landscape,
  });

  /// The game's small icon (about 32 px).
  final File? icon;

  /// A small, already blurred copy of the wide banner over the game's library
  /// page, which Steam shows while the banner loads.
  final File? heroBlur;

  /// The game's cover, the 2:3 capsule of Steam's library grid (300x450 or
  /// 600x900).
  final File? portrait;

  /// The game's header, the 460x215 capsule of its store page.
  final File? landscape;

  bool get isEmpty =>
      icon == null && heroBlur == null && portrait == null && landscape == null;
}

/// A file name in the hash-named library cache layout: the icon is stored
/// under the SHA-1 of its content.
final _hashedImagePattern = RegExp(r'^[0-9a-f]{40}\.jpg$');

/// The names Steam has stored each image under, preferred first.
const _heroBlurNames = ['library_hero_blur.jpg'];
const _portraitNames = ['library_600x900.jpg', 'library_capsule.jpg'];
const _landscapeNames = ['library_header.jpg', 'header.jpg'];

/// Finds the cached art of [steamAppId] in the first of [roots] that has any.
///
/// Steam has stored its library cache in three layouts:
/// - per game directory, each image in a hash-named subdirectory:
///   `librarycache/<id>/<hash>/library_hero_blur.jpg`;
/// - per game directory: `librarycache/<id>/library_hero_blur.jpg`;
/// - flat (older clients): `librarycache/<id>_library_hero_blur.jpg` and
///   `librarycache/<id>_icon.jpg`.
///
/// The per-game directories keep the icon as `librarycache/<id>/<sha1>.jpg`.
///
/// Steam fills the cache for the games its library has shown, so a game can
/// have none of it.
SteamLibraryArt findSteamLibraryArt(String steamAppId, Iterable<String> roots) {
  for (final root in roots) {
    final cache = p.join(root, 'appcache', 'librarycache');
    final gameDirectory = Directory(p.join(cache, steamAppId));

    File? icon;
    var subdirectories = const <Directory>[];
    if (gameDirectory.existsSync()) {
      try {
        final entities = gameDirectory.listSync(followLinks: false);
        icon = entities.whereType<File>().where((file) {
          return _hashedImagePattern.hasMatch(p.basename(file.path));
        }).firstOrNull;
        subdirectories = entities.whereType<Directory>().toList();
      } on FileSystemException {
        // An unreadable directory has no usable art.
      }
    }
    File? find(List<String> names) {
      for (final name in names) {
        final image = _findCachedImage(
          name,
          gameDirectory: gameDirectory,
          subdirectories: subdirectories,
          flat: File(p.join(cache, '${steamAppId}_$name')),
        );
        if (image != null) return image;
      }
      return null;
    }

    final flatIcon = File(p.join(cache, '${steamAppId}_icon.jpg'));
    if (icon == null && flatIcon.existsSync()) icon = flatIcon;

    final art = SteamLibraryArt(
      icon: icon,
      heroBlur: find(_heroBlurNames),
      portrait: find(_portraitNames),
      landscape: find(_landscapeNames),
    );
    if (!art.isEmpty) return art;
  }
  return const SteamLibraryArt();
}

/// The cached image [name] of a game, in whichever layout holds it.
File? _findCachedImage(
  String name, {
  required Directory gameDirectory,
  required List<Directory> subdirectories,
  required File flat,
}) {
  final direct = File(p.join(gameDirectory.path, name));
  if (direct.existsSync()) return direct;
  final nested = [
    for (final directory in subdirectories)
      if (File(p.join(directory.path, name)) case final file
          when file.existsSync())
        file,
  ];
  if (nested.isNotEmpty) {
    // A replaced image can leave its old directory: the newest wins.
    return nested.reduce(
      (a, b) => b.lastModifiedSync().isAfter(a.lastModifiedSync()) ? b : a,
    );
  }
  return flat.existsSync() ? flat : null;
}

/// Steam's `appinfo.vdf` headers: the magic number of each version, and where
/// its app records start. Version 29 adds a string table offset.
const _appInfoRecordsStart = {0x07564427: 8, 0x07564428: 8, 0x07564429: 16};

final _hashPattern = RegExp('(?<![0-9a-f])[0-9a-f]{40}(?![0-9a-f])');

/// The SHA-1 hashes named in the record of [steamAppId] in [appInfo], the
/// content of Steam's `appcache/appinfo.vdf`; empty when the file has no such
/// record or a format this does not know.
///
/// The record holds the hashes of the game's images, among them its client
/// icon's. The record's key-value data is not parsed: Steam names its files by
/// these hashes, so the caller keeps the one a file exists for.
Iterable<String> steamAppInfoHashes(Uint8List appInfo, String steamAppId) {
  final appId = int.tryParse(steamAppId);
  if (appId == null || appInfo.length < 8) return const [];
  final data = ByteData.sublistView(appInfo);
  var offset = _appInfoRecordsStart[data.getUint32(0, Endian.little)];
  if (offset == null) return const [];
  // Each record: the app id, the size of the rest, then the rest. A zero app
  // id ends the records.
  while (offset! + 8 <= appInfo.length) {
    final recordAppId = data.getUint32(offset, Endian.little);
    if (recordAppId == 0) break;
    final size = data.getUint32(offset + 4, Endian.little);
    final start = offset + 8;
    final end = start + size;
    if (end > appInfo.length) break;
    if (recordAppId == appId) {
      final record = latin1.decode(Uint8List.sublistView(appInfo, start, end));
      return _hashPattern.allMatches(record).map((match) => match[0]!);
    }
    offset = end;
  }
  return const [];
}

/// Finds the client icon of [steamAppId] in the first of [roots] that has it:
/// the `steam/games/<sha1>.ico` Steam keeps for the games it installed, which
/// holds the icon up to 256 px, unlike the library cache's 32 px one.
///
/// Its hash comes from the game's record in `appcache/appinfo.vdf`.
Future<File?> findSteamClientIcon(
  String steamAppId,
  Iterable<String> roots,
) async {
  for (final root in roots) {
    final appInfo = File(p.join(root, 'appcache', 'appinfo.vdf'));
    final Uint8List bytes;
    try {
      bytes = await appInfo.readAsBytes();
    } on FileSystemException {
      continue;
    }
    for (final hash in steamAppInfoHashes(bytes, steamAppId)) {
      final icon = File(p.join(root, 'steam', 'games', '$hash.ico'));
      if (icon.existsSync()) return icon;
    }
  }
  return null;
}
