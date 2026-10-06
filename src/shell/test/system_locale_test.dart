import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/settings/model/system_locale.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/system_locale.dart';
import 'package:shell/settings/provider/util/configured_settings_json.dart';
import 'package:shell/settings/widget/locale/system_locale_editor.dart';
import 'package:shell/shared/widget/expandable_container.dart';

const _installed = [
  'C',
  'C.UTF-8',
  'POSIX',
  'de_DE.UTF-8',
  'en_US.UTF-8',
  'fr_FR',
  'fr_FR.UTF-8',
];

ProviderContainer _container(_FakeLocaleService service) {
  final container = ProviderContainer(
    overrides: [
      systemLocaleServiceProvider.overrideWith((ref) => service),
      installedSystemLocalesProvider.overrideWith((ref) async => _installed),
      configuredSettingsJsonProvider.overrideWith(_EmptySettings.new),
      connectedMonitorListProvider.overrideWith(_NoMonitors.new),
    ],
  )..listen(systemLocaleProvider, (_, _) {});
  addTearDown(container.dispose);
  addTearDown(service.close);
  return container;
}

Widget _root(_FakeLocaleService service, {bool localeListFails = false}) {
  final container = ProviderContainer(
    overrides: [
      systemLocaleServiceProvider.overrideWith((ref) => service),
      installedSystemLocalesProvider.overrideWith((ref) async {
        if (localeListFails) throw const ProcessException('locale', ['-a']);
        return _installed;
      }),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: SystemLocaleEditor(),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pickFrench(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('LANG:en_US.UTF-8')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('fr_FR').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('expanded locale loading stays compact until dropdown is ready', (
    tester,
  ) async {
    final readReady = Completer<void>();
    final installedReady = Completer<List<String>>();
    final service = _FakeLocaleService({'LANG': 'en_US.UTF-8'})
      ..readGate = readReady.future;
    addTearDown(service.close);
    final container = ProviderContainer(
      overrides: [
        systemLocaleServiceProvider.overrideWith((ref) => service),
        installedSystemLocalesProvider.overrideWith(
          (ref) => installedReady.future,
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                child: ExpandableContainer(
                  builder: (context, {required isExpanded}) => isExpanded
                      ? const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: SystemLocaleEditor(),
                          ),
                        )
                      : TextButton(
                          onPressed: () =>
                              ExpandableContainer.of(context).expand(),
                          child: const Text('Open'),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final loadingServiceHeight = tester
        .getSize(find.byType(SystemLocaleEditor))
        .height;
    expect(loadingServiceHeight, lessThanOrEqualTo(80));
    readReady.complete();
    await tester.pump();
    await tester.pump();
    expect(
      tester.getSize(find.byType(SystemLocaleEditor)).height,
      loadingServiceHeight,
    );
    installedReady.complete(_installed);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(SystemLocaleEditor)).height,
      closeTo(loadingServiceHeight, 8),
    );
    expect(tester.takeException(), isNull);
  });
  test('installed locales are canonicalized, deduplicated and validated', () {
    expect(
      parseInstalledSystemLocales(
        'C\nC.utf8\nen_US.utf8\nen_US.UTF-8\n\n../bad\nnot a locale\n',
      ),
      ['C', 'C.UTF-8', 'POSIX', 'en_US.UTF-8'],
    );
    expect(canonicalSystemLocale('sr_RS.utf8@latin'), 'sr_RS.UTF-8@latin');
  });

  test('locale choices hide encodings and prefer installed UTF-8 variants', () {
    expect(
      preferredSystemLocales([
        'fr_FR',
        'fr_FR.utf8',
        'fr_FR.ISO-8859-1',
        'de_DE.ISO-8859-1',
        'sr_RS.utf8@latin',
        'sr_RS.utf8',
      ]),
      {
        'de_DE': 'de_DE.ISO-8859-1',
        'fr_FR': 'fr_FR.UTF-8',
        'sr_RS': 'sr_RS.UTF-8',
        'sr_RS@latin': 'sr_RS.UTF-8@latin',
      },
    );
    expect(systemLocaleName('sr_RS.utf8@latin'), 'sr_RS@latin');
  });

  test(
    'merge preserves unrelated overrides and removes only requested values',
    () {
      expect(
        applySystemLocaleChanges(
          {
            'LANG': 'en_US.UTF-8',
            'LC_TIME': 'de_DE.UTF-8',
            'LANGUAGE': 'en:de',
          },
          {'LANG': 'fr_FR.utf8'},
          _installed,
        ),
        {'LANG': 'fr_FR.UTF-8', 'LC_TIME': 'de_DE.UTF-8', 'LANGUAGE': 'en:de'},
      );
      expect(
        applySystemLocaleChanges(
          {'LANG': 'en_US.UTF-8', 'LC_TIME': 'de_DE.UTF-8'},
          {'LC_TIME': null},
          _installed,
        ),
        {'LANG': 'en_US.UTF-8'},
      );
      expect(
        () => applySystemLocaleChanges({}, {
          'LANG': 'not_installed.UTF-8',
        }, _installed),
        throwsArgumentError,
      );
      expect(
        () => applySystemLocaleChanges({}, {'LC_ALL': 'C'}, _installed),
        throwsArgumentError,
      );
      expect(
        () => applySystemLocaleChanges({}, {
          'LANG': 'fr_FR.UTF-8\nLC_ALL=C',
        }, _installed),
        throwsArgumentError,
      );
    },
  );

  test('assignments preserve values containing equals signs', () {
    expect(parseSystemLocaleAssignments(['LANG=C', 'invalid', 'TEST=a=b']), {
      'LANG': 'C',
      'TEST': 'a=b',
    });
  });

  test('message locales respect overrides, encodings, scripts and C', () {
    expect(systemMessageLocales({'LANG': 'fr_FR.UTF-8'}), [
      const Locale('fr', 'FR'),
    ]);
    expect(
      systemMessageLocales({
        'LANG': 'fr_FR.UTF-8',
        'LC_MESSAGES': 'en_GB.UTF-8',
      }),
      [const Locale('en', 'GB')],
    );
    expect(
      systemMessageLocales({'LANG': 'de_DE.UTF-8', 'LANGUAGE': 'fr:en:fr'}),
      [const Locale('fr'), const Locale('en'), const Locale('de', 'DE')],
    );
    expect(systemMessageLocales({'LANG': 'sr_RS.utf8@latin'}), [
      const Locale.fromSubtags(
        languageCode: 'sr',
        countryCode: 'RS',
        scriptCode: 'Latn',
      ),
    ]);
    expect(systemMessageLocales({'LANG': 'C.UTF-8', 'LANGUAGE': 'fr'}), [
      const Locale('en', 'US'),
    ]);
    expect(systemMessageLocales({'LANG': 'bad/value'}), [
      const Locale('en', 'US'),
    ]);
  });

  test(
    'saving French updates system-language matching without a session restart',
    () async {
      final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher
        ..localesTestValue = const [Locale('en', 'US')];
      addTearDown(dispatcher.clearLocalesTestValue);
      final service = _FakeLocaleService({'LANG': 'en_US.UTF-8'});
      final container = _container(service);
      final subscription = container.listen(
        settingsPropertiesProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final original = await container.read(systemLocaleProvider.future);
      expect(
        container.read(settingsPropertiesProvider)['system']!.children,
        contains('language'),
      );
      expect(container.read(systemLanguageSupportedProvider), isTrue);
      final french = await container
          .read(systemLocaleProvider.notifier)
          .apply(expected: original, changes: {'LANG': 'fr_FR.UTF-8'});
      expect(
        container.read(settingsPropertiesProvider)['system']!.children,
        contains('language'),
      );
      expect(container.read(systemLanguageSupportedProvider), isFalse);
      expect(container.read(systemLocalesProvider), const [Locale('en', 'US')]);
      await container.read(systemLocaleProvider.future);
      await container
          .read(systemLocaleProvider.notifier)
          .apply(expected: french, changes: {'LANG': 'en_US.UTF-8'});
      expect(
        container.read(settingsPropertiesProvider)['system']!.children,
        contains('language'),
      );
      expect(container.read(systemLanguageSupportedProvider), isTrue);
    },
  );

  test(
    'reading French disables system-language matching on English sessions',
    () async {
      final service = _FakeLocaleService({'LANG': 'fr_FR.UTF-8'});
      final container = _container(service);
      await container.read(systemLocaleProvider.future);
      expect(container.read(systemLanguageSupportedProvider), isFalse);
      expect(container.read(shellLocaleProvider), const Locale('en'));
    },
  );

  test('save sends the complete configuration and refreshes state', () async {
    final service = _FakeLocaleService({
      'LANG': 'en_US.UTF-8',
      'LC_TIME': 'de_DE.UTF-8',
    });
    final container = _container(service);
    final original = await container.read(systemLocaleProvider.future);
    await container
        .read(systemLocaleProvider.notifier)
        .apply(expected: original, changes: {'LANG': 'fr_FR.UTF-8'});
    expect(service.writes, [
      {'LANG': 'fr_FR.UTF-8', 'LC_TIME': 'de_DE.UTF-8'},
    ]);
    expect(await container.read(systemLocaleProvider.future), service.values);
  });

  test(
    'concurrent edits and invalid locales do not reach the writer',
    () async {
      final service = _FakeLocaleService({'LANG': 'en_US.UTF-8'});
      final container = _container(service);
      final original = await container.read(systemLocaleProvider.future);
      service.values = {'LANG': 'de_DE.UTF-8'};
      await expectLater(
        container
            .read(systemLocaleProvider.notifier)
            .apply(expected: original, changes: {'LANG': 'fr_FR.UTF-8'}),
        throwsA(isA<SystemLocaleConflict>()),
      );
      await expectLater(
        container
            .read(systemLocaleProvider.notifier)
            .apply(
              expected: service.values,
              changes: {'LANG': 'missing.UTF-8'},
            ),
        throwsArgumentError,
      );
      expect(service.writes, isEmpty);
    },
  );

  test('no-op saves do not request authorization', () async {
    final service = _FakeLocaleService({'LANG': 'en_US.UTF-8'});
    final container = _container(service);
    final original = await container.read(systemLocaleProvider.future);
    await container
        .read(systemLocaleProvider.notifier)
        .apply(expected: original, changes: {'LANG': 'en_US.utf8'});
    expect(service.writes, isEmpty);
  });

  test('failed saves do not change system-language matching', () async {
    final service = _FakeLocaleService({'LANG': 'en_US.UTF-8'})
      ..writeError = DBusMethodResponseException(
        DBusMethodErrorResponse('org.freedesktop.DBus.Error.AccessDenied'),
      );
    final container = _container(service);
    final original = await container.read(systemLocaleProvider.future);
    expect(container.read(systemLanguageSupportedProvider), isTrue);
    await expectLater(
      container
          .read(systemLocaleProvider.notifier)
          .apply(expected: original, changes: {'LANG': 'fr_FR.UTF-8'}),
      throwsA(isA<DBusMethodResponseException>()),
    );
    expect(container.read(systemLanguageSupportedProvider), isTrue);
    expect(container.read(veshellLocalePreferencesProvider), const [
      Locale('en', 'US'),
    ]);
  });

  testWidgets('edits are staged and successful saves explain session restart', (
    tester,
  ) async {
    final service = _FakeLocaleService({
      'LANG': 'en_US.UTF-8',
      'LC_TIME': 'de_DE.UTF-8',
    });
    addTearDown(service.close);
    await tester.pumpWidget(_root(service));
    await tester.pumpAndSettle();
    await _pickFrench(tester);
    expect(service.writes, isEmpty);
    await tester.ensureVisible(find.byTooltip('Apply'));
    await tester.tap(find.byTooltip('Apply'));
    await tester.pumpAndSettle();
    expect(service.writes.single, {
      'LANG': 'fr_FR.UTF-8',
      'LC_TIME': 'de_DE.UTF-8',
    });
    expect(
      find.textContaining('Existing applications may need a new session'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('authorization failure retains edits and allows retry', (
    tester,
  ) async {
    final service = _FakeLocaleService({'LANG': 'en_US.UTF-8'})
      ..writeError = DBusMethodResponseException(
        DBusMethodErrorResponse('org.freedesktop.DBus.Error.AccessDenied'),
      );
    addTearDown(service.close);
    await tester.pumpWidget(_root(service));
    await tester.pumpAndSettle();
    await _pickFrench(tester);
    await tester.ensureVisible(find.byTooltip('Apply'));
    await tester.tap(find.byTooltip('Apply'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Authorization was denied or cancelled'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('LANG:fr_FR.UTF-8')), findsOneWidget);
    expect(service.values, {'LANG': 'en_US.UTF-8'});
    service.writeError = null;
    await tester.ensureVisible(find.byTooltip('Apply'));
    await tester.tap(find.byTooltip('Apply'));
    await tester.pumpAndSettle();
    expect(service.values, {'LANG': 'fr_FR.UTF-8'});
  });

  testWidgets('external changes preserve dirty drafts until reset', (
    tester,
  ) async {
    final service = _FakeLocaleService({'LANG': 'en_US.UTF-8'});
    addTearDown(service.close);
    await tester.pumpWidget(_root(service));
    await tester.pumpAndSettle();
    await _pickFrench(tester);
    service
      ..values = {'LANG': 'de_DE.UTF-8'}
      ..notify();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('LANG:fr_FR.UTF-8')), findsOneWidget);
    expect(
      find.textContaining('changed while you were editing'),
      findsOneWidget,
    );
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Reset edits'));
    await tester.tap(find.text('Reset edits'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('LANG:de_DE.UTF-8')), findsOneWidget);
    expect(service.writes, isEmpty);
  });

  testWidgets('missing locale1 offers a retry instead of editable defaults', (
    tester,
  ) async {
    final service = _FakeLocaleService({})
      ..readError = StateError('Service unavailable');
    addTearDown(service.close);
    await tester.pumpWidget(_root(service));
    await tester.pumpAndSettle();
    expect(find.textContaining('systemd-localed'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    service.readError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets('external changes refresh an unedited form', (tester) async {
    final service = _FakeLocaleService({'LANG': 'en_US.UTF-8'});
    addTearDown(service.close);
    await tester.pumpWidget(_root(service));
    await tester.pumpAndSettle();
    service
      ..values = {'LANG': 'de_DE.UTF-8'}
      ..notify();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('LANG:de_DE.UTF-8')), findsOneWidget);
    expect(find.textContaining('changed while you were editing'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting the original locale discards edits without writing', (
    tester,
  ) async {
    final service = _FakeLocaleService({'LANG': 'en_US.UTF-8'});
    addTearDown(service.close);
    await tester.pumpWidget(_root(service));
    await tester.pumpAndSettle();
    await _pickFrench(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('en_US').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('LANG:en_US.UTF-8')), findsOneWidget);
    expect(service.writes, isEmpty);
  });

  testWidgets('one locale control lists each locale once without encodings', (
    tester,
  ) async {
    final service = _FakeLocaleService({
      'LANG': 'fr_FR',
      'LC_MESSAGES': 'en_US.UTF-8',
      'LC_TIME': 'de_DE.UTF-8',
    });
    addTearDown(service.close);
    await tester.pumpWidget(_root(service));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('Changes affect all users'), findsNothing);
    expect(find.textContaining('Only installed locales'), findsNothing);
    expect(service.writes, isEmpty);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    // The current legacy value remains untouched, even though a new selection
    // of this locale will prefer its installed UTF-8 variant.
    expect(find.byKey(const ValueKey('LANG:fr_FR')), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('fr_FR.UTF-8'), findsNothing);
    // One item in the popup and one selected value behind it, not two variants.
    expect(find.text('fr_FR'), findsNWidgets(2));
    await tester.tap(find.text('en_US').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Apply'));
    await tester.pumpAndSettle();
    expect(service.writes.single, {
      'LANG': 'en_US.UTF-8',
      'LC_MESSAGES': 'en_US.UTF-8',
      'LC_TIME': 'de_DE.UTF-8',
    });
  });

  testWidgets('missing locale command disables editing', (tester) async {
    final service = _FakeLocaleService({'LANG': 'C'});
    addTearDown(service.close);
    await tester.pumpWidget(_root(service, localeListFails: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('locale command is installed'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(service.writes, isEmpty);
  });

  test(
    'locale1 uses the real D-Bus contract and interactive authorization',
    () async {
      final server = DBusServer();
      final address = await server.listenAddress(
        DBusAddress.unix(
          abstract:
              'veshell-locale-test-$pid-'
              '${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      final owner = DBusClient(address);
      final client = DBusClient(address);
      final object = _Locale1Object();
      addTearDown(() async {
        await client.close();
        await owner.close();
        await server.close();
      });
      await owner.requestName('org.freedesktop.locale1');
      await owner.registerObject(object);
      final service = Locale1Service(client);
      expect(await service.read(), {'LANG': 'C'});
      await service.write({'LC_TIME': 'de_DE.UTF-8', 'LANG': 'fr_FR.UTF-8'});
      final call = object.lastCall!;
      expect(call.interface, 'org.freedesktop.locale1');
      expect(call.name, 'SetLocale');
      expect(call.signature, DBusSignature('asb'));
      expect(call.values[0].asStringArray(), [
        'LANG=fr_FR.UTF-8',
        'LC_TIME=de_DE.UTF-8',
      ]);
      expect(call.values[1].asBoolean(), isTrue);
      expect(call.allowInteractiveAuthorization, isTrue);
      final changed = Completer<void>();
      var notifications = 0;
      final subscription = service.changes.listen((_) {
        notifications++;
        if (!changed.isCompleted) changed.complete();
      });
      addTearDown(subscription.cancel);
      // A round trip ensures the signal match is registered before emitting.
      await service.read();
      await object.emitPropertiesChanged(
        'org.freedesktop.locale1',
        changedProperties: {'X11Layout': const DBusString('fr')},
      );
      await object.emitPropertiesChanged(
        'other.interface',
        invalidatedProperties: ['Locale'],
      );
      await object.emitPropertiesChanged(
        'org.freedesktop.locale1',
        invalidatedProperties: ['Locale'],
      );
      await changed.future.timeout(const Duration(seconds: 5));
      expect(notifications, 1);
    },
  );
}

class _FakeLocaleService implements SystemLocaleService {
  _FakeLocaleService(this.values);
  Map<String, String> values;
  Error? readError;
  Exception? writeError;
  Future<void>? readGate;
  final writes = <Map<String, String>>[];
  final _changes = StreamController<void>.broadcast();

  void notify() => _changes.add(null);
  Future<void> close() => _changes.close();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Map<String, String>> read() async {
    if (readGate case final Future<void> gate) await gate;
    if (readError case final Error error) throw error;
    return Map.unmodifiable(values);
  }

  @override
  Future<void> write(Map<String, String> assignments) async {
    if (writeError case final Exception error) throw error;
    values = Map.of(assignments);
    writes.add(Map.of(assignments));
    notify();
  }
}

class _Locale1Object extends DBusObject {
  _Locale1Object() : super(DBusObjectPath('/org/freedesktop/locale1'));
  DBusMethodCall? lastCall;

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async =>
      DBusGetPropertyResponse(DBusArray.string(['LANG=C']));

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    lastCall = methodCall;
    return DBusMethodSuccessResponse();
  }
}

class _EmptySettings extends ConfiguredSettingsJson {
  @override
  Map<String, dynamic> build() => {};
}

class _NoMonitors extends ConnectedMonitorList {
  @override
  List<Monitor> build() => [];
}
