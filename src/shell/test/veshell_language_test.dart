import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/settings/model/setting_group.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/config_directory.dart';
import 'package:shell/settings/provider/util/configured_settings_json.dart';
import 'package:shell/settings/provider/util/default_settings_json.dart';
import 'package:shell/settings/widget/locale/veshell_language_editor.dart';
import 'package:shell/shared/widget/expandable_container.dart';

void main() {
  testWidgets('the inline language check closes the expanded editor', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        settingsPropertiesProvider.overrideWith(_RecordingSettings.new),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      settingsPropertiesProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigator,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ExpandableContainer(
              builder: (context, {required isExpanded}) => isExpanded
                  ? const Material(child: VeshellLanguageEditor())
                  : TextButton(
                      onPressed: () => ExpandableContainer.of(context).expand(),
                      child: const Text('Open'),
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(navigator.currentState!.canPop(), isTrue);
    await tester.tap(find.byTooltip('Apply'));
    await tester.pumpAndSettle();
    expect(navigator.currentState!.canPop(), isFalse);
    final recording =
        container.read(settingsPropertiesProvider.notifier)
            as _RecordingSettings;
    expect(recording._lastPath, 'system.language');
    expect(tester.takeException(), isNull);
  });
  test('matching considers all system preferences and regional variants', () {
    const supported = [Locale('en'), Locale('fr')];
    expect(
      hasSupportedSystemLanguage(const [Locale('de')], supported),
      isFalse,
    );
    expect(
      hasSupportedSystemLanguage(const [
        Locale('de'),
        Locale('en', 'GB'),
      ], supported),
      isTrue,
    );
    expect(hasSupportedSystemLanguage(const [], supported), isFalse);
    expect(
      hasSupportedSystemLanguage(
        const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')],
        const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')],
      ),
      isFalse,
    );
  });

  test(
    'explicit preference overrides the system and rejects unshipped tags',
    () {
      const supported = [Locale('en'), Locale('fr')];
      expect(
        resolveVeshellLocale(const [Locale('de')], supported, preference: 'fr'),
        const Locale('fr'),
      );
      expect(
        resolveVeshellLocale(const [Locale('de')], supported, preference: 'xx'),
        const Locale('en'),
      );
      expect(
        resolveVeshellLocale(
          const [Locale('en', 'GB')],
          supported,
          preference: 'fr',
        ),
        const Locale('fr'),
      );
      expect(
        resolveVeshellLocale(
          const [Locale('de'), Locale('fr', 'CA')],
          supported,
          preference: 'en',
        ),
        const Locale('en'),
      );
    },
  );

  test('Settings always shows the picker after the system locale', () {
    final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher
      ..localesTestValue = const [Locale('zz')];
    addTearDown(dispatcher.clearLocalesTestValue);
    final container = ProviderContainer(
      overrides: [
        configuredSettingsJsonProvider.overrideWith(_EmptySettings.new),
        connectedMonitorListProvider.overrideWith(_NoMonitors.new),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      settingsPropertiesProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    expect(container.read(systemLanguageSupportedProvider), isFalse);
    expect(
      container.read(settingsPropertiesProvider)['system']!.children,
      contains('language'),
    );
    expect(container.read(shellLocaleProvider), const Locale('en'));
    expect(
      container.read(settingsPropertiesProvider)['system']!.children.keys,
      ['locale', 'language'],
    );
    dispatcher.localesTestValue = const [Locale('de'), Locale('en', 'GB')];
    expect(container.read(systemLanguageSupportedProvider), isTrue);
    expect(container.read(veshellFollowsSystemProvider), isTrue);
    expect(
      container.read(settingsPropertiesProvider)['system']!.children,
      contains('language'),
    );
  });

  testWidgets('picker lists only shipped catalogs and persists immediately', (
    tester,
  ) async {
    final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher
      ..localesTestValue = const [Locale('zz')];
    addTearDown(dispatcher.clearLocalesTestValue);
    final directory = Directory(
      '/tmp/opencode',
    ).createTempSync('veshell-language-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/settings.json')
      ..writeAsStringSync(jsonEncode({'unrelated': true}));
    ProviderContainer newContainer() => ProviderContainer(
      overrides: [
        configDirectoryProvider.overrideWith((ref) => directory),
        defaultSettingsJsonProvider.overrideWith(_LanguageDefaults.new),
        connectedMonitorListProvider.overrideWith(_NoMonitors.new),
        veshellLanguagePreferenceProvider.overrideWith(
          configuredVeshellLanguagePreference,
        ),
      ],
    );
    final container = newContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: VeshellLanguageEditor()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(
      dropdown.items!.map((item) => item.value),
      AppLocalizations.supportedLocales.map((locale) => locale.toLanguageTag()),
    );
    expect(find.text('English'), findsOneWidget);
    await tester.runAsync(() async {
      dropdown.onChanged!('en');
      expect(container.read(veshellLanguagePreferenceProvider), isNull);
      tester.widget<IconButton>(find.byType(IconButton)).onPressed!();
      // Publication must not wait for the debounced writer.
      expect(container.read(veshellLanguagePreferenceProvider), 'en');
      expect(container.read(shellLocaleProvider), const Locale('en'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(jsonDecode(file.readAsStringSync()), {
      'unrelated': true,
      'system': {'language': 'en'},
    });
    final reopened = newContainer();
    addTearDown(reopened.dispose);
    expect(reopened.read(veshellLanguagePreferenceProvider), 'en');
    expect(reopened.read(shellLocaleProvider), const Locale('en'));

    container.read(configuredSystemLocalesProvider.notifier).update(const [
      Locale('en', 'US'),
    ]);
    await tester.pumpAndSettle();
    final matchingDropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(matchingDropdown.items!.map((item) => item.value), [
      '',
      ...AppLocalizations.supportedLocales.map(
        (locale) => locale.toLanguageTag(),
      ),
    ]);
    expect(matchingDropdown.value, 'en');
    expect(container.read(veshellFollowsSystemProvider), isFalse);
    await tester.runAsync(() async {
      matchingDropdown.onChanged!('');
      expect(container.read(veshellLanguagePreferenceProvider), 'en');
      tester.widget<IconButton>(find.byType(IconButton)).onPressed!();
      expect(container.read(veshellLanguagePreferenceProvider), isNull);
      expect(container.read(veshellFollowsSystemProvider), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('Same as system'), findsOneWidget);
    expect(jsonDecode(file.readAsStringSync()), {'unrelated': true});
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .value,
      '',
    );
    expect(tester.takeException(), isNull);
  });
}

class _EmptySettings extends ConfiguredSettingsJson {
  @override
  Map<String, dynamic> build() => {};
}

class _LanguageDefaults extends DefaultSettingsJson {
  @override
  Map<String, dynamic> build() => {
    'system': <String, dynamic>{'language': null},
  };
}

class _NoMonitors extends ConnectedMonitorList {
  @override
  List<Monitor> build() => [];
}

class _RecordingSettings extends SettingsProperties {
  String? _lastPath;

  @override
  Map<String, SettingGroup> build() => {};

  @override
  void updateProperty(String path, dynamic newValue) {
    _lastPath = path;
  }
}
