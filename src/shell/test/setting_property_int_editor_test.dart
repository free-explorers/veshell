import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/settings/model/setting_group.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_editor_activation.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';

const _screenId = 'test';
const _path = 'keyboard.repeatDelayMs';
const _property = SettingProperty<int>(
  name: 'Key repeat delay',
  description: 'Delay before key repeat',
);
const _boolPath = 'mouseAndTouchpad.mouseNaturalScrolling';
const _boolProperty = SettingProperty<bool>(
  name: 'Natural scrolling',
  description: 'Use natural scrolling on the mouse',
);

/// Records what the editor writes without touching `settings.json`.
class _RecordingSettings extends SettingsProperties {
  final List<(String, dynamic)> saved = [];

  @override
  Map<String, SettingGroup> build() => const {};

  @override
  void updateProperty(String path, dynamic newValue) {
    saved.add((path, newValue));
  }
}

void main() {
  testWidgets('a setting requested from the search opens its editor focused', (
    tester,
  ) async {
    final settings = _RecordingSettings();
    final container = ProviderContainer(
      overrides: [
        jsonValueByPathProvider(_path).overrideWithValue(300),
        settingsPropertiesProvider.overrideWith(() => settings),
      ],
    );
    addTearDown(container.dispose);
    final navigator = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: CurrentScreenId(
          screenId: _screenId,
          child: MaterialApp(
            navigatorKey: navigator,
            localizationsDelegates: shellLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => _property.build(context, _path),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(navigator.currentState!.canPop(), isFalse);

    container
        .read(settingsEditorActivationProvider(_screenId).notifier)
        .request(_path);
    await tester.pumpAndSettle();

    expect(navigator.currentState!.canPop(), isTrue);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);

    await tester.enterText(find.byType(TextField), '450');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(settings.saved, [(_path, 450)]);
    expect(navigator.currentState!.canPop(), isFalse);
  });

  testWidgets('a boolean setting requested from the search toggles in place', (
    tester,
  ) async {
    final settings = _RecordingSettings();
    final container = ProviderContainer(
      overrides: [
        jsonValueByPathProvider(_boolPath).overrideWithValue(false),
        settingsPropertiesProvider.overrideWith(() => settings),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: CurrentScreenId(
          screenId: _screenId,
          child: MaterialApp(
            localizationsDelegates: shellLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => _boolProperty.build(context, _boolPath),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    container
        .read(settingsEditorActivationProvider(_screenId).notifier)
        .request(_boolPath);
    await tester.pumpAndSettle();

    expect(settings.saved, [(_boolPath, true)]);
  });
}
