import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/provider/desktop_entries.dart';

/// Polls [read] until [predicate] holds, then returns the value. Filesystem
/// watches are asynchronous, so the tests wait for the refresh instead of
/// asserting immediately.
Future<T> _waitFor<T>(
  T Function() read,
  bool Function(T) predicate, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final value = read();
    if (predicate(value)) return value;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('Timed out waiting for the desktop entries to refresh: ${read()}');
}

void main() {
  late Directory root;
  late Directory applications;

  setUp(() {
    root = Directory.systemTemp.createTempSync('veshell-desktop-entries');
    applications = Directory('${root.path}/applications')..createSync();
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  void writeEntry(String id, String name) {
    File('${applications.path}/$id.desktop').writeAsStringSync('''
[Desktop Entry]
Type=Application
Name=$name
Exec=$id
''');
  }

  ProviderContainer createContainer(Directory directory) {
    final container = ProviderContainer(
      overrides: [
        applicationDirectoriesProvider.overrideWith((ref) => [directory]),
      ],
    );
    addTearDown(container.dispose);
    // Real consumers (the app grid, overview search) watch the provider. Keep
    // a listener so an invalidation from the filesystem watcher rebuilds
    // immediately instead of waiting for the next subscriber.
    final subscription = container.listen(
      installedDesktopEntriesProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    return container;
  }

  test('picks up an application installed while running', () async {
    writeEntry('first', 'First');
    final container = createContainer(applications);

    final initial = await container.read(
      installedDesktopEntriesProvider.future,
    );
    expect(initial.keys, ['first']);

    writeEntry('second', 'Second');

    final refreshed = await _waitFor(
      () => container.read(installedDesktopEntriesProvider).value,
      (entries) => entries != null && entries.containsKey('second'),
    );
    expect(refreshed!.keys, containsAll(['first', 'second']));
  });

  test('drops an application removed while running', () async {
    writeEntry('first', 'First');
    writeEntry('second', 'Second');
    final container = createContainer(applications);

    final initial = await container.read(
      installedDesktopEntriesProvider.future,
    );
    expect(initial.keys, containsAll(['first', 'second']));

    File('${applications.path}/second.desktop').deleteSync();

    final refreshed = await _waitFor(
      () => container.read(installedDesktopEntriesProvider).value,
      (entries) => entries != null && !entries.containsKey('second'),
    );
    expect(refreshed!.keys, ['first']);
  });

  test(
    'picks up entries once a missing application directory appears',
    () async {
      // The directory the shell knows about does not exist yet: only its parent
      // is watchable at startup.
      final nested = Directory('${root.path}/nested')..createSync();
      final appeared = Directory('${nested.path}/applications');
      final container = createContainer(appeared);

      final initial = await container.read(
        installedDesktopEntriesProvider.future,
      );
      expect(initial, isEmpty);

      appeared.createSync();
      File('${appeared.path}/first.desktop').writeAsStringSync('''
[Desktop Entry]
Type=Application
Name=First
Exec=first
''');

      final refreshed = await _waitFor(
        () => container.read(installedDesktopEntriesProvider).value,
        (entries) => entries != null && entries.containsKey('first'),
      );
      expect(refreshed!.keys, ['first']);
    },
  );
}
