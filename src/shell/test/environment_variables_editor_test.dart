import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/settings/model/setting_group.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/settings/widget/environment/environment_variables_editor.dart';
import 'package:shell/shared/widget/expandable_container.dart';

const _path = 'environment.variables';

const _property = SettingProperty<Map<String, String>>(
  name: 'Environment variables',
  description: 'Variables applied to applications launched by Veshell',
);

/// Records what the editor writes without touching `settings.json`.
class _FakeSettingsProperties extends SettingsProperties {
  final List<(String, Map<String, String>)> saved = [];

  @override
  Map<String, SettingGroup> build() => const {};

  @override
  void updateProperty(String path, dynamic newValue) {
    saved.add((path, Map<String, String>.from(newValue as Map)));
  }
}

Widget _app(_FakeSettingsProperties fake, Map<String, String> stored) =>
    ProviderScope(
      overrides: [
        jsonValueByPathProvider(_path).overrideWithValue(stored),
        settingsPropertiesProvider.overrideWith(() => fake),
      ],
      child: MaterialApp(
        localizationsDelegates: shellLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ExpandableContainer(
            builder: (context, {required isExpanded}) =>
                const EnvironmentVariablesEditor(
                  path: _path,
                  property: _property,
                ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('stages rows and saves a name/value map', (tester) async {
    final fake = _FakeSettingsProperties();
    await tester.pumpWidget(_app(fake, {'EXISTING': '1'}));

    expect(find.text('EXISTING'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pump();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(4));
    await tester.enterText(fields.at(2), 'QT_STYLE_OVERRIDE');
    await tester.enterText(fields.at(3), 'Adwaita');

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(fake.saved.length, 1);
    expect(fake.saved.single.$1, _path);
    expect(fake.saved.single.$2, {
      'EXISTING': '1',
      'QT_STYLE_OVERRIDE': 'Adwaita',
    });
  });

  testWidgets('a duplicated name blocks the save with a message', (
    tester,
  ) async {
    final fake = _FakeSettingsProperties();
    await tester.pumpWidget(_app(fake, {'A': '1', 'B': '2'}));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'B');

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(fake.saved, isEmpty);
    expect(
      find.text(
        lookupAppLocalizations(const Locale('en')).environmentVariableInvalid,
      ),
      findsOneWidget,
    );
  });
}
