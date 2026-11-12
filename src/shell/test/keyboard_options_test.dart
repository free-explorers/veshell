// The ProviderScope a helper builds here is the root scope handed to
// pumpWidget; the lint only recognises a root scope written inline there.
// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/settings/model/keyboard_choices.dart';
import 'package:shell/settings/model/keyboard_option.dart';
import 'package:shell/settings/model/setting_group.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/keyboard_layout.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/settings/widget/keyboard/keyboard_options_editor.dart';
import 'package:shell/settings/widget/primitive/setting_property_choice_editor.dart';
import 'package:shell/shared/widget/expandable_container.dart';
import 'package:shell/shared/widget/shell_icon.dart';

const _optionsPath = 'keyboard.options';
const _optionsProperty = SettingProperty<List<String>>(
  name: 'Keyboard options',
  description: 'More XKB options',
  converter: KeyboardOptionsConverter(),
);

const _composePath = 'keyboard.composeKey';
const _composeProperty = SettingProperty<String>(
  name: 'Compose key',
  description: 'The key that starts a compose sequence',
);

const _switching = KeyboardOptionGroup(
  name: 'grp',
  description: 'Switching to another layout',
  allowsMultiple: false,
  options: [
    KeyboardOption(name: 'grp:alt_shift_toggle', description: 'Alt+Shift'),
    KeyboardOption(name: 'grp:win_space_toggle', description: 'Win+Space'),
  ],
);

const _ctrl = KeyboardOptionGroup(
  name: 'ctrl',
  description: 'Ctrl position',
  allowsMultiple: true,
  options: [
    KeyboardOption(name: 'ctrl:nocaps', description: 'Caps Lock as Ctrl'),
    KeyboardOption(name: 'ctrl:swap_lalt_lctl', description: 'Swap Alt'),
  ],
);

const _compose = KeyboardOptionGroup(
  name: 'Compose key',
  description: 'Position of Compose key',
  allowsMultiple: true,
  options: [KeyboardOption(name: 'compose:ralt', description: 'Right Alt')],
);

const List<KeyboardOptionGroup> _catalogue = [_switching, _ctrl, _compose];

/// Records what the editors write without touching `settings.json`.
class _FakeSettingsProperties extends SettingsProperties {
  final List<(String, dynamic)> saved = [];

  @override
  Map<String, SettingGroup> build() => const {};

  @override
  void updateProperty(String path, dynamic newValue) {
    saved.add((path, newValue));
  }
}

Widget _app(
  _FakeSettingsProperties fake,
  String path,
  Object? stored,
  Widget editor,
) => ProviderScope(
  overrides: [
    jsonValueByPathProvider(path).overrideWithValue(stored),
    availableKeyboardOptionsProvider.overrideWith((ref) async => _catalogue),
    settingsPropertiesProvider.overrideWith(() => fake),
  ],
  child: MaterialApp(
    localizationsDelegates: shellLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: ExpandableContainer(
          builder: (context, {required isExpanded}) => Material(child: editor),
        ),
      ),
    ),
  ),
);

void main() {
  group('parseKeyboardOptions', () {
    test('reads a list and drops blank entries', () {
      expect(parseKeyboardOptions(['ctrl:nocaps', ' ', 3, ' grp:x ']), [
        'ctrl:nocaps',
        'grp:x',
      ]);
    });

    test('reads the xkb-native comma-separated string', () {
      expect(parseKeyboardOptions('ctrl:nocaps, compose:ralt'), [
        'ctrl:nocaps',
        'compose:ralt',
      ]);
    });

    test('reads a missing value as no option', () {
      expect(parseKeyboardOptions(null), isEmpty);
    });
  });

  test('KeyboardOptionGroup.fromJson reads the catalogue entry', () {
    final group = KeyboardOptionGroup.fromJson(const {
      'name': 'grp',
      'description': 'Switching to another layout',
      'allowsMultiple': false,
      'options': [
        {'name': 'grp:alt_shift_toggle', 'description': 'Alt+Shift'},
        'malformed',
      ],
    });
    expect(group.allowsMultiple, isFalse);
    expect(group.options.single.name, 'grp:alt_shift_toggle');
  });

  test('the picker leaves out the options dedicated settings own', () {
    final names = keyboardOptionEntries(
      _catalogue,
    ).map((entry) => entry.option.name);
    expect(names, [
      'grp:alt_shift_toggle',
      'grp:win_space_toggle',
      'ctrl:swap_lalt_lctl',
    ]);
  });

  test('an entry label ends with its xkb code, so the filter finds it', () {
    final entry = keyboardOptionEntries(_catalogue).first;
    expect(
      entry.label,
      'Switching to another layout: Alt+Shift - grp:alt_shift_toggle',
    );
  });

  group('keepLastOfExclusiveGroups', () {
    test('keeps only the last pick of a single-choice group', () {
      expect(
        keepLastOfExclusiveGroups([
          'grp:alt_shift_toggle',
          'ctrl:swap_lalt_lctl',
          'grp:win_space_toggle',
        ], _catalogue),
        ['ctrl:swap_lalt_lctl', 'grp:win_space_toggle'],
      );
    });

    test('keeps every option of a multiple-choice group and unknown ones', () {
      final options = ['ctrl:nocaps', 'ctrl:swap_lalt_lctl', 'custom:thing'];
      expect(keepLastOfExclusiveGroups(options, _catalogue), options);
    });
  });

  test('every compose key maps to a catalogue-style compose option', () {
    expect(composeKeys.first, 'none');
    expect(curatedKeyboardOptions, contains('compose:ralt'));
    expect(curatedKeyboardOptions, isNot(contains('compose:none')));
  });

  testWidgets('saves the picked options as a list', (tester) async {
    final fake = _FakeSettingsProperties();
    await tester.pumpWidget(
      _app(
        fake,
        _optionsPath,
        ['grp:alt_shift_toggle', 'custom:hand_edited'],
        const KeyboardOptionsEditor(
          path: _optionsPath,
          property: _optionsProperty,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DropdownMenu<KeyboardOptionEntry>), findsNWidgets(2));

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final (path, value) = fake.saved.single;
    expect(path, _optionsPath);
    expect(value, ['grp:alt_shift_toggle', 'custom:hand_edited']);
  });

  testWidgets('the compose key picker saves the picked key', (tester) async {
    final fake = _FakeSettingsProperties();
    await tester.pumpWidget(
      _app(
        fake,
        _composePath,
        null,
        const SettingPropertyChoiceEditor(
          path: _composePath,
          property: _composeProperty,
          choices: composeKeys,
          defaultValue: 'none',
          label: composeKeyLabel,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Unset reads as none, which is checked.
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'None'),
        matching: find.byType(ShellIcon),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Right Alt'));
    await tester.pumpAndSettle();

    expect(fake.saved.single, (_composePath, 'ralt'));
  });
}
