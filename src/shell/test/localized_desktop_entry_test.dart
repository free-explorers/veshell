import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';

LocalizedDesktopEntry _entry({String? exec, String? startupWmClass}) =>
    LocalizedDesktopEntry(
      desktopEntry: const DesktopEntry(entries: {}),
      entries: {
        DesktopEntryKey.exec.string: ?exec,
        DesktopEntryKey.startupWmClass.string: ?startupWmClass,
      },
    );

ProviderContainer _container(Map<String, LocalizedDesktopEntry> entries) {
  final container = ProviderContainer(
    overrides: [
      localizedDesktopEntriesProvider.overrideWith((ref) async => entries),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('resolves an app id that is a desktop file id', () async {
    final brave = _entry(exec: '/usr/bin/brave');
    final container = _container({'brave': brave});

    final resolved = await container.read(
      localizedDesktopEntryForIdProvider('brave').future,
    );

    expect(resolved, same(brave));
  });

  test('resolves an app id through the binary name', () async {
    final brave = _entry(exec: '/usr/bin/brave');
    final container = _container({'brave-browser': brave});

    final resolved = await container.read(
      localizedDesktopEntryForIdProvider('brave').future,
    );

    expect(resolved, same(brave));
  });

  test('resolves an app id through the startup WM class', () async {
    final brave = _entry(exec: '/usr/bin/brave', startupWmClass: 'Brave');
    final container = _container({'brave-browser': brave});

    final resolved = await container.read(
      localizedDesktopEntryForIdProvider('Brave').future,
    );

    expect(resolved, same(brave));
  });

  test('returns null for an unknown app id', () async {
    final container = _container({});

    final resolved = await container.read(
      localizedDesktopEntryForIdProvider('unknown').future,
    );

    expect(resolved, isNull);
  });
}
