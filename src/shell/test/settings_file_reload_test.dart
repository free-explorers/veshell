import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/settings/provider/util/config_directory.dart';
import 'package:shell/settings/provider/util/configured_settings_json.dart';
import 'package:shell/settings/provider/util/file_creation_watch.dart';

/// Waits for [condition] to hold, as file watch events arrive asynchronously.
Future<bool> eventually(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      return false;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return true;
}

/// Replaces [path] the way scripts and the shell do: a temporary file renamed
/// onto it.
void writeByRename(String path, String content) {
  File('$path.tmp')
    ..writeAsStringSync(content)
    ..renameSync(path);
}

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('settings_reload');
  });

  tearDown(() {
    directory.deleteSync(recursive: true);
  });

  /// A container whose configuration directory carries a trailing slash, as
  /// the default `~/.config/veshell/` used to.
  ProviderContainer containerWithTrailingSlash() {
    final container = ProviderContainer(
      overrides: [
        configDirectoryProvider.overrideWithValue(
          Directory('${directory.path}/'),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(configuredSettingsJsonProvider, (_, _) {});
    return container;
  }

  /// Whether the configured theme color in [container] becomes [color].
  Future<bool> themeColorBecomes(ProviderContainer container, String color) =>
      eventually(() {
        final theme =
            container.read(configuredSettingsJsonProvider)['theme']
                as Map<String, dynamic>?;
        return theme?['color'] == color;
      });

  test('settings.json created by a rename is followed, and so are later '
      'edits', () async {
    final container = containerWithTrailingSlash();
    expect(container.read(configuredSettingsJsonProvider), isEmpty);

    final path = '${directory.path}/settings.json';
    writeByRename(path, '{"theme":{"color":"0xFF1C2EB7"}}');
    expect(await themeColorBecomes(container, '0xFF1C2EB7'), isTrue);

    writeByRename(path, '{"theme":{"color":"0xFF003380"}}');
    expect(await themeColorBecomes(container, '0xFF003380'), isTrue);
  });

  test('settings.json created by a plain write is followed', () async {
    final container = containerWithTrailingSlash();

    File(
      '${directory.path}/settings.json',
    ).writeAsStringSync('{"theme":{"color":"0xFF1C2EB7"}}');
    expect(await themeColorBecomes(container, '0xFF1C2EB7'), isTrue);
  });

  test('a file in a subdirectory is watched in that subdirectory', () async {
    final monitorDirectory = Directory('${directory.path}/monitor')
      ..createSync();
    final created = Completer<void>();
    final subscription = watchFileCreation(
      File('${directory.path}//monitor/DP-1.json'),
      created.complete,
    );
    addTearDown(subscription.cancel);
    // Let the watch start before the file appears.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    writeByRename('${monitorDirectory.path}/DP-1.json', '{}');
    await created.future.timeout(const Duration(seconds: 3));
  });
}
