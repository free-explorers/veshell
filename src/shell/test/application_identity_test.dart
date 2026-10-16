import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:shell/application/model/application_identity.dart';

LocalizedDesktopEntry _entry({
  required String id,
  String? exec,
  String? tryExec,
  String? wmClass,
}) {
  final entries = <String, String>{};
  if (exec != null) entries[DesktopEntryKey.exec.string] = exec;
  if (tryExec != null) entries[DesktopEntryKey.tryExec.string] = tryExec;
  if (wmClass != null) {
    entries[DesktopEntryKey.startupWmClass.string] = wmClass;
  }
  return LocalizedDesktopEntry(
    desktopEntry: DesktopEntry(entries: const {}, id: id),
    entries: entries,
  );
}

void main() {
  // The real pair from a typical install: the same program under a generic and
  // a KDE-only entry.
  final gnome = _entry(
    id: 'org.gnome.SystemMonitor',
    exec: 'gnome-system-monitor',
    tryExec: 'gnome-system-monitor',
    wmClass: 'gnome-system-monitor',
  );
  final kde = _entry(
    id: 'gnome-system-monitor-kde',
    exec: 'gnome-system-monitor',
    tryExec: 'gnome-system-monitor',
    wmClass: 'gnome-system-monitor',
  );
  // Two unrelated entries that happen to share an executable (a real trap:
  // `gnome-control-center` has 28 such entries on this system).
  final settings = _entry(
    id: 'org.gnome.Settings',
    exec: 'gnome-control-center',
  );
  final settingsOther = _entry(
    id: 'org.gnome.Settings.Other',
    exec: 'gnome-control-center',
  );
  final steam = _entry(id: 'steam', exec: 'steam');
  final game = _entry(id: 'game-xyz', exec: '/usr/bin/game');
  final brave = _entry(id: 'brave-browser', exec: 'brave');
  final hermes = _entry(
    id: 'hermes-desktop',
    exec: 'hermes',
    wmClass: 'Hermes',
  );

  final entries = <String, LocalizedDesktopEntry>{
    for (final entry in [
      gnome,
      kde,
      settings,
      settingsOther,
      steam,
      game,
      brave,
      hermes,
    ])
      entry.desktopEntry.id!: entry,
  };
  final binaryToAppId = <String, String?>{
    'gnome-system-monitor': 'org.gnome.SystemMonitor',
    'steam': 'steam',
    'brave': 'brave-browser',
    'hermes': 'hermes-desktop',
  };

  group('resolveLocalizedDesktopEntry', () {
    test('resolves an exact entry id', () {
      expect(
        resolveLocalizedDesktopEntry(
          appId: 'steam',
          entries: entries,
          binaryToAppId: binaryToAppId,
        ),
        same(steam),
      );
    });

    test('resolves a binary name through binaryToAppId', () {
      expect(
        resolveLocalizedDesktopEntry(
          appId: 'gnome-system-monitor',
          entries: entries,
          binaryToAppId: binaryToAppId,
        )?.desktopEntry.id,
        'org.gnome.SystemMonitor',
      );
    });

    test('resolves a StartupWMClass case-insensitively', () {
      expect(
        resolveLocalizedDesktopEntry(
          appId: 'HERMES',
          entries: entries,
          binaryToAppId: binaryToAppId,
        )?.desktopEntry.id,
        'hermes-desktop',
      );
    });

    test('returns null for an unknown id', () {
      expect(
        resolveLocalizedDesktopEntry(
          appId: 'nope',
          entries: entries,
          binaryToAppId: binaryToAppId,
        ),
        isNull,
      );
    });
  });

  group('sameApplicationId', () {
    test('recognises a packaging alias by StartupWMClass', () {
      expect(
        sameApplicationId(
          a: 'org.gnome.SystemMonitor',
          b: 'gnome-system-monitor-kde',
          entries: entries,
          binaryToAppId: binaryToAppId,
        ),
        isTrue,
      );
    });

    test('does not merge two entries that only share an executable', () {
      expect(
        sameApplicationId(
          a: 'org.gnome.Settings',
          b: 'org.gnome.Settings.Other',
          entries: entries,
          binaryToAppId: binaryToAppId,
        ),
        isFalse,
      );
    });

    test('matches two ids that resolve to the same entry', () {
      expect(
        sameApplicationId(
          a: 'brave',
          b: 'brave-browser',
          entries: entries,
          binaryToAppId: binaryToAppId,
        ),
        isTrue,
      );
    });

    test('equal ids always match', () {
      expect(
        sameApplicationId(
          a: 'steam',
          b: 'steam',
          entries: entries,
          binaryToAppId: binaryToAppId,
        ),
        isTrue,
      );
    });
  });

  group('applicationsDiffer', () {
    bool differ(String reported, String launch) => applicationsDiffer(
      reportedAppId: reported,
      launchAppId: launch,
      entries: entries,
      binaryToAppId: binaryToAppId,
    );

    test('the system-monitor alias is not a conflict', () {
      expect(
        differ('org.gnome.SystemMonitor', 'gnome-system-monitor-kde'),
        isFalse,
      );
    });

    test('a shared executable is still a conflict', () {
      expect(differ('org.gnome.Settings', 'org.gnome.Settings.Other'), isTrue);
    });

    test('two different applications conflict', () {
      expect(differ('game-xyz', 'steam'), isTrue);
    });

    test('an empty reported id is not a conflict', () {
      expect(differ('', 'steam'), isFalse);
    });

    test('an unresolved reported id is not a conflict', () {
      expect(differ('Godot_Engine', 'steam'), isFalse);
    });

    test('an unresolved launch id is not a conflict', () {
      expect(differ('org.gnome.SystemMonitor', 'mystery'), isFalse);
    });
  });
}
