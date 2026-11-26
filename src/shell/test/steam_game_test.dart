import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:path/path.dart' as p;
import 'package:shell/application/model/application_identity.dart';
import 'package:shell/application/model/steam_game.dart';

/// An `appinfo.vdf` (version 29) holding [records], app id to record body.
Uint8List _appInfo(Map<int, String> records) {
  final bytes = BytesBuilder()
    ..add(_uint32(0x07564429))
    ..add(_uint32(1))
    // The string table offset, unused here.
    ..add(Uint8List(8));
  for (final MapEntry(key: appId, value: body) in records.entries) {
    final encoded = latin1.encode(body);
    bytes
      ..add(_uint32(appId))
      ..add(_uint32(encoded.length))
      ..add(encoded);
  }
  bytes.add(_uint32(0));
  return bytes.toBytes();
}

Uint8List _uint32(int value) =>
    (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();

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

    test('reads the banner from a hash-named subdirectory', () {
      final blur = touch(
        'a/appcache/librarycache/42/e38dad54f59519e592896c889bbfa7c9/'
        'library_hero_blur.jpg',
      );

      final art = findSteamLibraryArt('42', [p.join(temp.path, 'a')]);

      expect(art.heroBlur?.path, blur.path);
    });

    test('reads the cover and the header of each layout', () {
      final cover = touch('a/appcache/librarycache/42/library_600x900.jpg');
      final header = touch(
        'a/appcache/librarycache/42/5ae122faf933516f136578257fe9f6c6/'
        'library_header.jpg',
      );
      final flatCover = touch('b/appcache/librarycache/7_library_600x900.jpg');
      final flatHeader = touch('b/appcache/librarycache/7_header.jpg');
      final capsule = touch(
        'c/appcache/librarycache/9/82061d7868598ec310ee43f38122a5b3/'
        'library_capsule.jpg',
      );

      final a = findSteamLibraryArt('42', [p.join(temp.path, 'a')]);
      final b = findSteamLibraryArt('7', [p.join(temp.path, 'b')]);
      final c = findSteamLibraryArt('9', [p.join(temp.path, 'c')]);

      expect(a.portrait?.path, cover.path);
      expect(a.landscape?.path, header.path);
      expect(b.portrait?.path, flatCover.path);
      expect(b.landscape?.path, flatHeader.path);
      expect(c.portrait?.path, capsule.path);
      expect(c.landscape, isNull);
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

  group('steamAppInfoHashes', () {
    const icon = 'd84198725616ae43a74222f559e0fe710c3bb18b';
    const other = '746ad60be76401ebebf2bbfa485d8934b70c96e6';

    test("reads the hashes of the game's record only", () {
      final appInfo = _appInfo({
        7: 'clienticon\x00$other\x00',
        42:
            'icon\x00f6da1420a173324d49bcd470fa3eee781ad0fa5e\x00'
            'clienticon\x00$icon\x00',
      });

      expect(steamAppInfoHashes(appInfo, '42'), [
        'f6da1420a173324d49bcd470fa3eee781ad0fa5e',
        icon,
      ]);
      expect(steamAppInfoHashes(appInfo, '7'), [other]);
      expect(steamAppInfoHashes(appInfo, '8'), isEmpty);
    });

    test('ignores longer hex runs and unknown files', () {
      expect(
        steamAppInfoHashes(_appInfo({42: '${icon}ab\x00'}), '42'),
        isEmpty,
      );
      expect(steamAppInfoHashes(Uint8List.fromList([1, 2, 3]), '42'), isEmpty);
      expect(steamAppInfoHashes(Uint8List(16), '42'), isEmpty);
    });

    test('finds the client icon a file exists for', () async {
      final temp = Directory.systemTemp.createTempSync('steam_icon_');
      addTearDown(() => temp.deleteSync(recursive: true));
      File(p.join(temp.path, 'appcache', 'appinfo.vdf'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(
          _appInfo({42: 'icon\x00$other\x00clienticon\x00$icon\x00'}),
        );
      final ico = File(p.join(temp.path, 'steam', 'games', '$icon.ico'))
        ..createSync(recursive: true);

      final found = await findSteamClientIcon('42', [
        p.join(temp.path, 'missing'),
        temp.path,
      ]);

      expect(found?.path, ico.path);
      expect(await findSteamClientIcon('7', [temp.path]), isNull);
    });
  });
}
