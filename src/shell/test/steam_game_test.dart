import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:path/path.dart' as p;
import 'package:shell/application/model/application_identity.dart';
import 'package:shell/application/model/steam_game.dart';

LocalizedDesktopEntry _entry({required String id, String? exec}) {
  return LocalizedDesktopEntry(
    desktopEntry: DesktopEntry(entries: const {}, id: id),
    entries: {DesktopEntryKey.exec.string: ?exec},
  );
}

void main() {
  group('steamAppIdOfWindow', () {
    test('reads the id of a Proton window', () {
      expect(steamAppIdOfWindow('steam_app_1569580'), '1569580');
      expect(steamAppIdOfWindow('Steam_App_42'), '42');
    });

    test('ignores other windows', () {
      expect(steamAppIdOfWindow(null), isNull);
      expect(steamAppIdOfWindow('steam'), isNull);
      expect(steamAppIdOfWindow('steam_app_'), isNull);
      expect(steamAppIdOfWindow('steam_app_12x'), isNull);
      expect(steamAppIdOfWindow('org.gnome.Nautilus'), isNull);
    });
  });

  group('launchesSteamGame', () {
    test('matches the game URI in a shortcut command', () {
      expect(
        launchesSteamGame('steam steam://rungameid/1569580', '1569580'),
        isTrue,
      );
    });

    test('does not match another game sharing a prefix', () {
      expect(launchesSteamGame('steam steam://rungameid/123', '12'), isFalse);
      expect(launchesSteamGame('steam', '12'), isFalse);
      expect(launchesSteamGame(null, '12'), isFalse);
    });
  });

  test('steamRoots covers the native and Flatpak installs', () {
    expect(steamRoots(home: '/home/u'), [
      '/home/u/.steam/steam',
      '/home/u/.local/share/Steam',
      '/home/u/.var/app/com.valvesoftware.Steam/.local/share/Steam',
    ]);
    expect(steamRoots(home: '/home/u', dataHome: '/data')[1], '/data/Steam');
  });

  group('findSteamLibraryArt', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('steam_art_'));
    tearDown(() => temp.deleteSync(recursive: true));

    File touch(String path) => File(p.join(temp.path, path))
      ..createSync(recursive: true)
      ..writeAsBytesSync(const [0]);

    test('reads the per-game layout', () {
      const hash = '7807d6dcd71d8161465619b4f041794b0353a6d0';
      final icon = touch('a/appcache/librarycache/42/$hash.jpg');
      final blur = touch('a/appcache/librarycache/42/library_hero_blur.jpg');
      touch('a/appcache/librarycache/42/header.jpg');

      final art = findSteamLibraryArt('42', [p.join(temp.path, 'a')]);

      expect(art.icon?.path, icon.path);
      expect(art.heroBlur?.path, blur.path);
    });

    test('reads the flat layout of older clients', () {
      final icon = touch('a/appcache/librarycache/42_icon.jpg');
      final blur = touch('a/appcache/librarycache/42_library_hero_blur.jpg');

      final art = findSteamLibraryArt('42', [p.join(temp.path, 'a')]);

      expect(art.icon?.path, icon.path);
      expect(art.heroBlur?.path, blur.path);
    });

    test('skips roots without the game', () {
      touch('a/appcache/librarycache/7_icon.jpg');
      final icon = touch('b/appcache/librarycache/42_icon.jpg');

      final art = findSteamLibraryArt('42', [
        p.join(temp.path, 'missing'),
        p.join(temp.path, 'a'),
        p.join(temp.path, 'b'),
      ]);

      expect(art.icon?.path, icon.path);
      expect(art.heroBlur, isNull);
    });

    test('is empty for an uncached game', () {
      expect(findSteamLibraryArt('42', [temp.path]).isEmpty, isTrue);
    });
  });

  group('resolveLocalizedDesktopEntry for a Proton window', () {
    final shortcut = _entry(
      id: 'Blue Prince',
      exec: 'steam steam://rungameid/1569580',
    );
    final other = _entry(
      id: 'Other Game',
      exec: 'steam steam://rungameid/15695801',
    );
    final entries = {'Blue Prince': shortcut, 'Other Game': other};

    test("resolves the game's Steam shortcut", () {
      expect(
        resolveLocalizedDesktopEntry(
          appId: 'steam_app_1569580',
          entries: entries,
          binaryToAppId: const {},
        ),
        same(shortcut),
      );
    });

    test('stays unresolved without a shortcut', () {
      expect(
        resolveLocalizedDesktopEntry(
          appId: 'steam_app_7',
          entries: entries,
          binaryToAppId: const {},
        ),
        isNull,
      );
    });
  });
}
