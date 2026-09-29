import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/shared/util/json_converter/logical_key_set.dart';
import 'package:shell/shared/widget/hotkey_viewer.dart';

void main() {
  const path = 'keyboard.hotkeys.system.increaseVolume';

  testWidgets('a hotkey SettingProperty renders without throwing', (
    tester,
  ) async {
    const property = SettingProperty<LogicalKeySet>(
      name: 'Increase Volume',
      description: 'Increase the volume',
      converter: LogicalKeySetConverter(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jsonValueByPathProvider(path).overrideWithValue('ctrl+alt+m'),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) => property.build(context, path)),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(HotkeyViewer), findsOneWidget);
  });

  testWidgets('a malformed stored hotkey renders without throwing', (
    tester,
  ) async {
    const property = SettingProperty<LogicalKeySet>(
      name: 'Play/Pause Media',
      description: 'Toggle playback of the active media player',
      converter: LogicalKeySetConverter(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jsonValueByPathProvider(path).overrideWithValue('null')],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) => property.build(context, path)),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(HotkeyViewer), findsNothing);
    expect(find.text('Not set'), findsOneWidget);
  });
}
