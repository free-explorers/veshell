import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/settings/model/keyboard_layout.dart';
import 'package:shell/settings/model/setting_group.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/keyboard_layout.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/settings/widget/keyboard/keyboard_layouts_editor.dart';
import 'package:shell/shared/util/json_converter/logical_key_set.dart';
import 'package:shell/shared/widget/expandable_container.dart';

const _path = 'keyboard.layout';
const _property = SettingProperty<String>(
  name: 'Layout',
  description: 'Keyboard layout',
);

const _catalogue = <KeyboardLayoutOption>[
  KeyboardLayoutOption(layout: 'us', variant: '', description: 'English (US)'),
  KeyboardLayoutOption(
    layout: 'us',
    variant: 'altgr-intl',
    description: 'English (intl., with AltGr dead keys)',
  ),
  KeyboardLayoutOption(layout: 'ru', variant: '', description: 'Russian'),
];

/// Records what the editor writes without touching `settings.json`.
class _FakeSettingsProperties extends SettingsProperties {
  final List<(String, String)> saved = [];

  @override
  Map<String, SettingGroup> build() => const {};

  @override
  void updateProperty(String path, dynamic newValue) {
    saved.add((path, newValue as String));
  }
}

Widget _app(_FakeSettingsProperties fake, String stored) => ProviderScope(
  overrides: [
    jsonValueByPathProvider(_path).overrideWithValue(stored),
    availableKeyboardLayoutsProvider.overrideWith((ref) async => _catalogue),
    settingsPropertiesProvider.overrideWith(() => fake),
  ],
  child: MaterialApp(
    localizationsDelegates: shellLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ExpandableContainer(
        builder: (context, {required isExpanded}) =>
            const KeyboardLayoutsEditor(path: _path, property: _property),
      ),
    ),
  ),
);

void main() {
  group('parseKeyboardLayouts', () {
    test('returns an empty list for missing or blank values', () {
      expect(parseKeyboardLayouts(null), isEmpty);
      expect(parseKeyboardLayouts(''), isEmpty);
      expect(parseKeyboardLayouts('  ,  '), isEmpty);
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

  group('KeyboardLayoutOption', () {
    test('entry combines layout and variant', () {
      expect(_catalogue[0].entry, 'us');
      expect(_catalogue[1].entry, 'us(altgr-intl)');
    });

    test('fromJson tolerates missing fields', () {
      final option = KeyboardLayoutOption.fromJson(const {'layout': 'us'});
      expect(option.layout, 'us');
      expect(option.variant, '');
      expect(option.iso639, isEmpty);
    });
  });

  testWidgets('shows one picker per layout and can add another', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeSettingsProperties(), 'us,ru'));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownMenu<KeyboardLayoutOption>), findsNWidgets(2));

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownMenu<KeyboardLayoutOption>), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('saves the picked layouts comma-separated', (tester) async {
    final fake = _FakeSettingsProperties();
    await tester.pumpWidget(_app(fake, 'us,ru'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake.saved.single, (_path, 'us,ru'));
  });

  testWidgets('a stored entry outside the catalogue is preserved', (
    tester,
  ) async {
    final fake = _FakeSettingsProperties();
    await tester.pumpWidget(_app(fake, 'us(custom-variant)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake.saved.single, (_path, 'us(custom-variant)'));
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
