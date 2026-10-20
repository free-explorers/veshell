import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/settings/widget/keyboard/setting_property_hotkeys_editor.dart';
import 'package:shell/shared/util/json_converter/logical_key_set.dart';
import 'package:shell/shared/widget/hotkey_viewer.dart';
import 'package:shell/shared/widget/list_editor.dart';

void main() {
  const path = 'keyboard.hotkeys.system.increaseVolume';

  testWidgets('a hotkey list SettingProperty renders without throwing', (
    tester,
  ) async {
    const property = SettingProperty<List<LogicalKeySet>>(
      name: 'Increase Volume',
      description: 'Increase the volume',
      converter: LogicalKeySetListConverter(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jsonValueByPathProvider(
            path,
          ).overrideWithValue(['ctrl+alt+m', 'volumeUp']),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(builder: (context) => property.build(context, path)),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(HotkeyViewer), findsNWidgets(2));
  });

  testWidgets('a malformed stored hotkey renders without throwing', (
    tester,
  ) async {
    const property = SettingProperty<List<LogicalKeySet>>(
      name: 'Play/Pause Media',
      description: 'Toggle playback of the active media player',
      converter: LogicalKeySetListConverter(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jsonValueByPathProvider(path).overrideWithValue('null')],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

  testWidgets('a newly added binding takes the keyboard', (tester) async {
    const property = SettingProperty<List<LogicalKeySet>>(
      name: 'Increase Volume',
      description: 'Increase the volume',
      converter: LogicalKeySetListConverter(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jsonValueByPathProvider(path).overrideWithValue(['super+w']),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SettingPropertyHotkeysEditor(
              path: path,
              property: property,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editorBindings = find.descendant(
      of: find.byType(ListEditor),
      matching: find.byType(HotkeyViewer),
    );
    expect(editorBindings, findsOneWidget);

    // Focus the existing binding, then add another row. The chord typed next
    // must fill the new row instead of replacing the focused one.
    await tester.tap(editorBindings);
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    final chords = tester
        .widgetList<HotkeyViewer>(editorBindings)
        .map((viewer) => viewer.hotkey)
        .toList();
    expect(
      chords,
      unorderedEquals([
        LogicalKeySet.fromSet({
          LogicalKeyboardKey.superKey,
          LogicalKeyboardKey.keyW,
        }),
        LogicalKeySet.fromSet({
          LogicalKeyboardKey.controlLeft,
          LogicalKeyboardKey.keyQ,
        }),
      ]),
    );
  });
}
