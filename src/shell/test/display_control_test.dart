import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/helm/control_panel/display/provider/display_brightness.dart';
import 'package:shell/overview/helm/control_panel/display/provider/night_light_state.dart';
import 'package:shell/overview/helm/control_panel/display/widget/display_control.dart';
import 'package:shell/platform/model/event/brightness_changed/brightness_changed.serializable.dart';
import 'package:shell/platform/model/event/night_light_changed/night_light_changed.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/settings/model/night_light_choices.dart';
import 'package:shell/settings/provider/state/night_light_setting.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';

const _channel = MethodChannel('platform', JSONMethodCodec());

/// Delivers a compositor call to the shell, as the embedder would.
Future<void> _fromCompositor(String method, Map<String, Object?> args) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        _channel.name,
        _channel.codec.encodeMethodCall(MethodCall(method, args)),
        (_) {},
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> requests;

  setUp(() {
    requests = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          requests.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('platform events', () {
    test('night_light_changed decodes', () {
      final event = PlatformEvent.fromJson(const {
        'method': 'night_light_changed',
        'message': {'active': true, 'supported': false},
      });
      expect(event, isA<NightLightChangedEvent>());
      final message = (event as NightLightChangedEvent).message;
      expect(message.active, isTrue);
      expect(message.supported, isFalse);
    });

    test('brightness_changed carries its source and availability', () {
      final event = PlatformEvent.fromJson(const {
        'method': 'brightness_changed',
        'message': {'fraction': 0.5, 'available': false, 'source': 'sync'},
      });
      final message = (event as BrightnessChangedEvent).message;
      expect(message.available, isFalse);
      expect(message.source, BrightnessChangeSource.sync);
    });

    test('an older or unknown brightness report is a key press', () {
      final bare = BrightnessChangedMessage.fromJson(const {'fraction': 0.5});
      expect(bare.available, isTrue);
      expect(bare.source, BrightnessChangeSource.keys);
      final unknown = BrightnessChangedMessage.fromJson(const {
        'fraction': 0.5,
        'source': 'somewhere',
      });
      expect(unknown.source, BrightnessChangeSource.keys);
    });
  });

  group('providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
      final brightnessSub = container.listen(
        displayBrightnessProvider,
        (_, _) {},
      );
      addTearDown(brightnessSub.close);
      final nightLightSub = container.listen(
        nightLightStateProvider,
        (_, _) {},
      );
      addTearDown(nightLightSub.close);
    });

    test('mirror the compositor reports', () async {
      expect(container.read(displayBrightnessProvider), isNull);
      expect(container.read(nightLightStateProvider), isNull);

      await _fromCompositor('brightness_changed', {
        'fraction': 0.4,
        'available': true,
        'source': 'sync',
      });
      await _fromCompositor('night_light_changed', {
        'active': false,
        'supported': true,
      });

      expect(container.read(displayBrightnessProvider), 0.4);
      expect(
        container.read(nightLightStateProvider),
        NightLightChangedMessage(active: false, supported: true),
      );
    });

    test('no backlight means no brightness level', () async {
      await _fromCompositor('brightness_changed', {
        'fraction': 1.0,
        'available': false,
        'source': 'sync',
      });
      expect(container.read(displayBrightnessProvider), isNull);
    });

    test('the slider sets the level at once and ignores its echoes', () async {
      container.read(displayBrightnessProvider.notifier).set(0.8);
      expect(container.read(displayBrightnessProvider), 0.8);
      await pumpEventQueue();
      expect(requests.single.method, 'set_brightness');
      expect(requests.single.arguments, {'fraction': 0.8});

      // An echo of an earlier drag step must not pull the handle back.
      await _fromCompositor('brightness_changed', {
        'fraction': 0.6,
        'source': 'helm',
      });
      expect(container.read(displayBrightnessProvider), 0.8);

      // A key press still moves it.
      await _fromCompositor('brightness_changed', {
        'fraction': 0.85,
        'source': 'keys',
      });
      expect(container.read(displayBrightnessProvider), 0.85);
    });

    test('the toggle asks the compositor and shows the change', () async {
      await _fromCompositor('night_light_changed', {
        'active': false,
        'supported': true,
      });
      container
          .read(nightLightStateProvider.notifier)
          .setEnabled(enabled: true);
      expect(container.read(nightLightStateProvider)?.active, isTrue);
      await pumpEventQueue();
      expect(requests.single.method, 'set_night_light');
      expect(requests.single.arguments, {'enabled': true});
    });
  });

  group('schedule settings', () {
    test('times parse and serialize as HH:MM', () {
      expect(parseTimeOfDay('20:00'), const TimeOfDay(hour: 20, minute: 0));
      expect(parseTimeOfDay(' 6:05 '), const TimeOfDay(hour: 6, minute: 5));
      for (final bad in [null, 7, '', '24:00', '12:60', 'noon', '1:2:3']) {
        expect(parseTimeOfDay(bad), isNull, reason: '$bad');
      }
      expect(serializeTimeOfDay(const TimeOfDay(hour: 6, minute: 5)), '06:05');
    });

    test('the picker offers every half hour', () {
      expect(nightLightTimes, hasLength(48));
      expect(nightLightTimes.first, '00:00');
      expect(nightLightTimes[41], '20:30');
      expect(nightLightTimes, containsAll(['06:00', '20:00']));
    });

    test('the stored schedule falls back like the compositor', () {
      final container = ProviderContainer(
        overrides: [
          jsonValueByPathProvider(
            nightLightSchedulePath,
          ).overrideWithValue('manual'),
          jsonValueByPathProvider(
            nightLightFromPath,
          ).overrideWithValue('21:30'),
          jsonValueByPathProvider(nightLightToPath).overrideWithValue('bogus'),
        ],
      );
      addTearDown(container.dispose);
      final schedule = container.read(nightLightScheduleProvider);
      expect(schedule.scheduled, isTrue);
      expect(schedule.from, const TimeOfDay(hour: 21, minute: 30));
      expect(schedule.to, nightLightToFallback);
    });
  });

  group('nightLightSubtitle', () {
    // Material's localizations load the date formats in the app.
    setUpAll(() => initializeDateFormatting('en'));
    final l10n = lookupAppLocalizations(const Locale('en'));
    const scheduled = (
      scheduled: true,
      from: TimeOfDay(hour: 20, minute: 0),
      to: TimeOfDay(hour: 6, minute: 0),
    );

    test('on, it lasts until the window ends', () {
      expect(
        nightLightSubtitle(l10n, schedule: scheduled, active: true),
        'On until 6:00 AM',
      );
    });

    test('off, it waits for the window to start', () {
      expect(
        nightLightSubtitle(l10n, schedule: scheduled, active: false),
        'Off until 8:00 PM',
      );
    });

    test('says nothing without a schedule or with an empty window', () {
      const off = (
        scheduled: false,
        from: TimeOfDay(hour: 20, minute: 0),
        to: TimeOfDay(hour: 6, minute: 0),
      );
      expect(nightLightSubtitle(l10n, schedule: off, active: true), isNull);
      const empty = (
        scheduled: true,
        from: TimeOfDay(hour: 20, minute: 0),
        to: TimeOfDay(hour: 20, minute: 0),
      );
      expect(nightLightSubtitle(l10n, schedule: empty, active: true), isNull);
    });
  });

  group('Display card', () {
    Future<void> pumpSection(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nightLightScheduleProvider.overrideWithValue((
              scheduled: true,
              from: const TimeOfDay(hour: 20, minute: 0),
              to: const TimeOfDay(hour: 6, minute: 0),
            )),
          ],
          child: MaterialApp(
            localizationsDelegates: shellLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) =>
                    displaySection(ref) ?? const Text('no card'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('is absent until the compositor offers something', (
      tester,
    ) async {
      await pumpSection(tester);
      expect(find.text('no card'), findsOneWidget);

      await tester.runAsync(
        () => _fromCompositor('brightness_changed', {
          'fraction': 1.0,
          'available': false,
          'source': 'sync',
        }),
      );
      await tester.runAsync(
        () => _fromCompositor('night_light_changed', {
          'active': false,
          'supported': false,
        }),
      );
      await tester.pump();
      expect(find.text('no card'), findsOneWidget);
    });

    testWidgets('shows only the rows the compositor can drive', (tester) async {
      await pumpSection(tester);
      await tester.runAsync(
        () => _fromCompositor('night_light_changed', {
          'active': false,
          'supported': true,
        }),
      );
      await tester.pump();

      expect(find.text('Display'), findsOneWidget);
      expect(find.text('Night Light'), findsOneWidget);
      expect(find.text('Off until 8:00 PM'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);

      await tester.runAsync(
        () => _fromCompositor('brightness_changed', {
          'fraction': 0.5,
          'available': true,
          'source': 'sync',
        }),
      );
      await tester.pump();
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('the switch turns Night Light on', (tester) async {
      await pumpSection(tester);
      await tester.runAsync(
        () => _fromCompositor('night_light_changed', {
          'active': false,
          'supported': true,
        }),
      );
      await tester.pump();

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.runAsync(pumpEventQueue);

      expect(requests.single.method, 'set_night_light');
      expect(requests.single.arguments, {'enabled': true});
      expect(find.text('On until 6:00 AM'), findsOneWidget);
    });
  });
}
