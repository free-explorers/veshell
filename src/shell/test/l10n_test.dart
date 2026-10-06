import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart'
    as desktop;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/desktop_entries.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/capture/model/screen_cast_consent/screen_cast_consent.serializable.dart';
import 'package:shell/capture/provider/screen_cast_consent.dart';
import 'package:shell/capture/widget/screen_cast_consent.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/settings/model/types/monitor_setting.serializable.dart';
import 'package:shell/settings/provider/util/configured_settings_json.dart';
import 'package:shell/shared/util/relative_time.dart';

void main() {
  testWidgets('unnamed capture windows use the catalog fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          screenCastConsentProvider.overrideWith(_UnnamedWindowConsent.new),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Center(child: ScreenCastConsentPicker())),
        ),
      ),
    );
    expect(find.text('Untitled window'), findsOneWidget);
    expect(find.text('Share a window?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'desktop entries keep system translations when the shell falls back',
    () async {
      final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
      dispatcher.localesTestValue = const [Locale('fr', 'BE')];
      addTearDown(dispatcher.clearLocalesTestValue);
      final entry = desktop.DesktopEntry.parse('''
[Desktop Entry]
Type=Application
Name=Files
Name[fr]=Fichiers
Exec=files
''');
      final container = ProviderContainer(
        overrides: [
          configuredSettingsJsonProvider.overrideWith(_EmptySettings.new),
          veshellLanguagePreferenceProvider.overrideWith((ref) => 'en'),
          installedDesktopEntriesProvider.overrideWith(
            (ref) async => {'files': entry},
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(shellLocalizationsProvider).cancel, 'Cancel');
      final entries = await container.read(
        localizedDesktopEntriesProvider.future,
      );
      expect(entries['files']!.entries['Name'], 'Fichiers');
    },
  );

  test('English catalog handles counts, placeholders and transform labels', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(l10n.itemCount(0), 'No items');
    expect(l10n.itemCount(1), '1 item');
    expect(l10n.itemCount(2), '2 items');
    expect(l10n.cannotOpenPath('/home/a {b}'), 'Cannot open /home/a {b}');
    expect(
      l10n.displaySettingsCountdown('Resolution of DP-1', 1),
      'Resolution of DP-1. Reverting in 1 second unless you keep it.',
    );
    expect(
      l10n.displaySettingsCountdown('Resolution of DP-1', 2),
      'Resolution of DP-1. Reverting in 2 seconds unless you keep it.',
    );
    expect(MonitorTransform.flipped90.label(l10n), 'Flipped + Rotate 90°');
  });

  test('unsupported and regional system locales resolve safely', () {
    final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
    dispatcher.localesTestValue = const [Locale('zz'), Locale('en', 'GB')];
    addTearDown(dispatcher.clearLocalesTestValue);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(shellLocaleProvider), const Locale('en'));
    expect(container.read(shellLocalizationsProvider).cancel, 'Cancel');
    expect(container.read(systemLocalesProvider).first, const Locale('zz'));
    dispatcher.localesTestValue = const [Locale('en', 'US')];
    expect(container.read(systemLocalesProvider), const [Locale('en', 'US')]);
    final now = DateTime(2026);
    expect(formatRelativeTime(now, localeName: 'zz', now: now), 'Now');
    expect(formatRelativeTime(now, localeName: 'zh-Hans-CN', now: now), '现在');
    expect(formatRelativeTime(now, localeName: 'zh-TW', now: now), '現在');
    expect(formatRelativeTime(now, localeName: 'zh-Hant-HK', now: now), '現在');
  });

  testWidgets('monitor roots and dialogs share generated delegates', (
    tester,
  ) async {
    Widget root() => MaterialApp(
      locale: const Locale('en', 'GB'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) =>
                AlertDialog(title: Text(context.l10n.authenticate)),
          ),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
    await tester.pumpWidget(root());
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Authenticate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _EmptySettings extends ConfiguredSettingsJson {
  @override
  Map<String, dynamic> build() => {};
}

class _UnnamedWindowConsent extends ScreenCastConsent {
  @override
  ScreenCastConsentMessage build() => ScreenCastConsentMessage(
    sessionHandle: '/session/test',
    requestHandle: '/request/test',
    consentToken: 1,
    appName: 'Test app',
    sources: [
      ScreenCastSourceMessage(
        id: 'window-1',
        label: '',
        kind: CaptureSourceKind.windows,
      ),
    ],
  );
}
