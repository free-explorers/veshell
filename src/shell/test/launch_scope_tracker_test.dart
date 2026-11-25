import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shell/application/model/launch_scope_tracker.dart';

void main() {
  group('ScopeIdentity', () {
    bool scope(String appId, String name) => ScopeIdentity(appId).matches(name);

    test('recognizes each launcher naming style', () {
      expect(
        const ScopeIdentity.steamGame(
          '1422450',
        ).matches('app-steam-app1422450-44276.scope'),
        isTrue,
      );
      expect(
        scope(
          'com.rustdesk.RustDesk',
          'app-flatpak-com.rustdesk.RustDesk-12345.scope',
        ),
        isTrue,
      );
      expect(
        scope('org.chromium.Chromium', 'app-org.chromium.Chromium-2345.scope'),
        isTrue,
      );
      expect(scope('code-oss', 'app-code-oss-3456.scope'), isTrue);
      expect(
        scope('org.example.My-App', r'app-org.example.My\x2dApp-4242.scope'),
        isTrue,
      );
      expect(
        scope(
          'com.rustdesk.RustDesk',
          'app-flatpak-com.rustdesk.RustDesk-12345.scope',
        ),
        isTrue,
      );
    });

    test('never matches another application', () {
      // The tail of a longer id is no match: `code` is not a launcher.
      expect(scope('oss', 'app-code-oss-3456.scope'), isFalse);
      expect(scope('code', 'app-code-oss-3456.scope'), isFalse);
      expect(
        const ScopeIdentity.steamGame(
          '1422450',
        ).matches('app-steam-app14224500-1.scope'),
        isFalse,
      );
      expect(
        const ScopeIdentity.steamGame(
          '1422450',
        ).matches('app-flatpak-app1422450-1.scope'),
        isFalse,
      );
      expect(scope('code-oss', 'app-code-oss@autostart.service'), isFalse);
      expect(scope('code-oss', 'veshell-launch-code-oss-1.scope'), isFalse);
      expect(scope('', 'app--1.scope'), isFalse);
      // Only the launchers seen moving applications precede the id.
      expect(
        scope('org.gnome.Nautilus', 'app-gnome-org.gnome.Nautilus-4242.scope'),
        isFalse,
      );
    });

    test('escapes like systemd', () {
      expect(
        systemdEscape('org.gnome.Characters-x'),
        r'org.gnome.Characters\x2dx',
      );
      expect(systemdEscape('.hidden'), r'\x2ehidden');
      expect(systemdEscape('a b/c'), r'a\x20b\x2fc');
    });
  });

  group('LaunchScopeTracker', () {
    const slice = '/sys/fs/cgroup/user.slice/user-1000.slice/app.slice';

    late Map<String, StreamController<FileSystemEvent>> watched;
    late List<String> existing;
    late List<String> log;

    setUp(() {
      watched = {};
      existing = [];
      log = [];
    });

    tearDown(() async {
      for (final controller in watched.values) {
        await controller.close();
      }
    });

    LaunchScopeTracker track(ScopeIdentity identity) => LaunchScopeTracker(
      slicePath: slice,
      identity: identity,
      onStarted: (unit) => log.add('started $unit'),
      onEnded: (unit) => log.add('ended $unit'),
      watch: (directory) => watched
          .putIfAbsent(directory, StreamController<FileSystemEvent>.new)
          .stream,
      list: (_) => existing,
    );

    /// The watch of the directory [unit] lives in: the slice, or the D-Bus
    /// slice of a `<slice>/<service>` unit.
    StreamController<FileSystemEvent> parentOf(String unit) {
      final parent = unit.contains('/')
          ? '$slice/${unit.substring(0, unit.indexOf('/'))}'
          : slice;
      return watched[parent]!;
    }

    void create(String unit) =>
        parentOf(unit).add(FileSystemCreateEvent('$slice/$unit', true));

    void delete(String unit) =>
        parentOf(unit).add(FileSystemDeleteEvent('$slice/$unit', true));

    test('follows the game scope from its start to its end', () async {
      track(const ScopeIdentity.steamGame('1422450'));
      create('app-steam-app1422450-44276.scope');
      delete('app-steam-app1422450-44276.scope');
      await pumpEventQueue();

      expect(log, [
        'started app-steam-app1422450-44276.scope',
        'ended app-steam-app1422450-44276.scope',
      ]);
    });

    test('ignores other applications and other games', () async {
      final tracker = track(const ScopeIdentity.steamGame('1422450'));
      create('app-steam-app14224500-1.scope');
      create('app-steam-app570-2.scope');
      create('veshell-launch-abc.service');
      delete('app-steam-app1422450-3.scope');
      await pumpEventQueue();

      expect(log, isEmpty);
      expect(tracker.scope, isNull);
    });

    test('keeps to the first scope of the launch', () async {
      track(const ScopeIdentity.steamGame('1422450'));
      create('app-steam-app1422450-1.scope');
      create('app-steam-app1422450-2.scope');
      delete('app-steam-app1422450-2.scope');
      delete('app-steam-app1422450-1.scope');
      await pumpEventQueue();

      expect(log, [
        'started app-steam-app1422450-1.scope',
        'ended app-steam-app1422450-1.scope',
      ]);
    });

    test('reports nothing once cancelled', () async {
      track(const ScopeIdentity.steamGame('1422450')).cancel();
      create('app-steam-app1422450-1.scope');
      await pumpEventQueue();

      expect(log, isEmpty);
    });

    group('D-Bus activation', () {
      const busName = 'org.a11y.atspi.Registry';
      const dbusSlice = r'app-dbus\x2d:1.31\x2dorg.a11y.atspi.Registry.slice';
      const service = 'dbus-:1.31-org.a11y.atspi.Registry@0.service';

      test('follows the service of a newly created slice', () async {
        track(const ScopeIdentity(busName));
        create(dbusSlice);
        await pumpEventQueue();
        create('$dbusSlice/$service');
        delete('$dbusSlice/$service');
        await pumpEventQueue();

        expect(log, [
          'started $dbusSlice/$service',
          'ended $dbusSlice/$service',
        ]);
      });

      test('follows a service started in a slice left behind', () async {
        existing.add(dbusSlice);
        track(const ScopeIdentity(busName));
        create('$dbusSlice/$service');
        await pumpEventQueue();

        expect(log, ['started $dbusSlice/$service']);
      });

      test("ignores another bus name's slice and service", () async {
        existing.add(
          r'app-dbus\x2d:1.2\x2dorg.gnome.Settings.GlobalShortcutsProvider'
          '.slice',
        );
        track(const ScopeIdentity(busName));
        create(r'app-dbus\x2d:1.40\x2dorg.example.Other.slice');
        await pumpEventQueue();

        expect(watched.keys, [slice]);
        expect(log, isEmpty);
      });

      test('the Steam rule never follows D-Bus', () async {
        existing.add(r'app-dbus\x2d:1.31\x2dapp570.slice');
        track(const ScopeIdentity.steamGame('570'));

        expect(watched.keys, [slice]);
      });
    });
  });

  group('userAppSliceDirectory', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('veshell_cgroup_'));
    tearDown(() => root.deleteSync(recursive: true));

    test("finds the user manager's app slice", () {
      Directory(
        '${root.path}/user.slice/user-1000.slice/user@1000.service/app.slice',
      ).createSync(recursive: true);

      final slice = userAppSliceDirectory(
        cgroupRoot: root.path,
        procSelfStatus: 'Name:\tveshell\nUid:\t1000\t1000\t1000\t1000\n',
      );

      expect(slice?.path, endsWith('user@1000.service/app.slice'));
    });

    test('is null without a user manager', () {
      expect(
        userAppSliceDirectory(
          cgroupRoot: root.path,
          procSelfStatus: 'Uid:\t1000\t1000\t1000\t1000\n',
        ),
        isNull,
      );
    });
  });
}
