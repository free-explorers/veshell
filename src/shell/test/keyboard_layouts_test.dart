import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/settings/widget/keyboard/keyboard_layouts_editor.dart';
import 'package:shell/shared/util/json_converter/logical_key_set.dart';

void main() {
  group('parseKeyboardLayouts', () {
    test('returns an empty list for missing or blank values', () {
      expect(parseKeyboardLayouts(null), isEmpty);
      expect(parseKeyboardLayouts(''), isEmpty);
      expect(parseKeyboardLayouts('  ,  '), isEmpty);
    });

    test('keeps a single layout', () {
      expect(parseKeyboardLayouts('us'), ['us']);
    });

    test('splits a comma-separated list and trims whitespace', () {
      expect(parseKeyboardLayouts('us, ru'), ['us', 'ru']);
      expect(parseKeyboardLayouts('us,ru,'), ['us', 'ru']);
    });

    test('keeps a variant attached to its layout', () {
      expect(parseKeyboardLayouts('us(altgr-intl),ru'), [
        'us(altgr-intl)',
        'ru',
      ]);
    });
  });

  testWidgets('the editor shows one field per layout and can add another', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jsonValueByPathProvider('keyboard.layout').overrideWithValue('us,ru'),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: KeyboardLayoutsEditor(
              path: 'keyboard.layout',
              property: const SettingProperty<String>(
                name: 'Layout',
                description: 'Keyboard layout',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsNWidgets(2));

    await tester.tap(find.byIcon(MdiIcons.plus));
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  test('the shipped toggle binding parses into a logical key set', () {
    final binding = const LogicalKeySetConverter().fromJson('super+space');
    expect(
      binding,
      LogicalKeySet.fromSet({
        LogicalKeyboardKey.superKey,
        LogicalKeyboardKey.space,
      }),
    );
  });
}
