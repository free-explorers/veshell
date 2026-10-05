import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart' hide Notification;
import 'package:shell/notification/model/dbus_notification.serializable.dart';
import 'package:shell/notification/model/notification.serializable.dart'
    as model;
import 'package:shell/notification/model/notification_hints.serializable.dart';
import 'package:shell/notification/model/system_notification_category.dart';
import 'package:shell/notification/provider/notification_channel.dart';
import 'package:shell/notification/provider/system_notification_manager.dart';
import 'package:shell/notification/widget/notification_area.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/battery_notification.dart';
import 'package:shell/platform/model/event/brightness_changed/brightness_changed.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:upower/upower.dart';

const _screenId = 'screen-1';

model.Notification _systemNotification(int id) => model.Notification(
  id: id,
  appId: null,
  dbusNotification: const DbusNotification(
    pid: null,
    appName: 'System',
    replacesId: 0,
    appIcon: '',
    summary: 'Volume',
    body: '50%',
    actions: [],
    hints: NotificationHints(category: systemVolumeCategory, value: 50),
    expireTimeout: 0,
  ),
  createdAt: DateTime(2026),
  isSynthetic: true,
);

void main() {
  group('brightness_changed platform event', () {
    test('decodes the reported fraction', () {
      final event = PlatformEvent.fromJson(const {
        'method': 'brightness_changed',
        'message': {'fraction': 0.42},
      });

      expect(event, isA<BrightnessChangedEvent>());
      expect((event as BrightnessChangedEvent).message.fraction, 0.42);
    });
  });

  group('nextBatteryWarning', () {
    BatteryWarning decide({
      UPowerDeviceState state = UPowerDeviceState.discharging,
      UPowerDeviceWarningLevel warningLevel = UPowerDeviceWarningLevel.none,
      double percentage = 50,
      int lowThreshold = 20,
      int criticalThreshold = 10,
      bool lowWarned = false,
      bool criticalWarned = false,
    }) => nextBatteryWarning(
      state: state,
      warningLevel: warningLevel,
      percentage: percentage,
      lowThreshold: lowThreshold,
      criticalThreshold: criticalThreshold,
      lowWarned: lowWarned,
      criticalWarned: criticalWarned,
    );

    test('stays silent while charging', () {
      expect(
        decide(state: UPowerDeviceState.charging, percentage: 5),
        BatteryWarning.none,
      );
    });

    test('warns low at the low threshold', () {
      expect(decide(percentage: 20), BatteryWarning.low);
      expect(decide(percentage: 19), BatteryWarning.low);
    });

    test('warns critical at the critical threshold, not low', () {
      expect(decide(percentage: 10), BatteryWarning.critical);
      expect(decide(percentage: 9), BatteryWarning.critical);
    });

    test('does not repeat a warning already raised', () {
      expect(decide(percentage: 15, lowWarned: true), BatteryWarning.none);
      expect(
        decide(percentage: 5, lowWarned: true, criticalWarned: true),
        BatteryWarning.none,
      );
      // A critical level still warns even after the low warning.
      expect(decide(percentage: 5, lowWarned: true), BatteryWarning.critical);
    });

    test('honors UPower warning levels alongside the thresholds', () {
      expect(
        decide(warningLevel: UPowerDeviceWarningLevel.low),
        BatteryWarning.low,
      );
      expect(
        decide(warningLevel: UPowerDeviceWarningLevel.critical),
        BatteryWarning.critical,
      );
      expect(
        decide(warningLevel: UPowerDeviceWarningLevel.action),
        BatteryWarning.critical,
      );
    });
  });

  group('SystemNotificationManager', () {
    late StreamController<PlatformEvent> events;
    late ProviderContainer container;

    setUp(() {
      events = StreamController<PlatformEvent>.broadcast();
      addTearDown(events.close);
      container = ProviderContainer(
        overrides: [
          platformManagerProvider.overrideWithValue(events.stream),
          focusedScreenProvider.overrideWithValue(_screenId),
        ],
      );
      addTearDown(container.dispose);
      // Keep the manager and the screen channel alive for the test.
      final managerSub = container.listen(
        systemNotificationManagerProvider,
        (_, _) {},
      );
      addTearDown(managerSub.close);
      final channelSub = container.listen(
        notificationChannelProvider(_screenId),
        (_, _) {},
      );
      addTearDown(channelSub.close);
    });

    test('shows a volume notification with a level bar', () {
      container
          .read(systemNotificationManagerProvider.notifier)
          .showVolume(volume: 0.5, muted: false);

      final notifications = container.read(
        notificationChannelProvider(_screenId),
      );
      expect(notifications, hasLength(1));
      final notification = notifications.first;
      expect(notification.isSynthetic, isTrue);
      expect(notification.id, lessThan(0));
      expect(
        notification.dbusNotification.hints.category,
        systemVolumeCategory,
      );
      expect(notification.dbusNotification.hints.value, 50);
      expect(notification.dbusNotification.summary, 'Volume');
      expect(notification.dbusNotification.body, '50%');
    });

    test('muting shows an empty muted bar', () {
      container
          .read(systemNotificationManagerProvider.notifier)
          .showVolume(volume: 0.5, muted: true);

      final notification = container
          .read(notificationChannelProvider(_screenId))
          .single;
      expect(
        notification.dbusNotification.hints.category,
        systemVolumeMutedCategory,
      );
      expect(notification.dbusNotification.hints.value, 0);
      expect(notification.dbusNotification.body, 'Muted');
    });

    test('re-showing the same kind replaces its popup in place', () {
      final manager = container.read(systemNotificationManagerProvider.notifier)
        ..showVolume(volume: 0.5, muted: false);

      final firstId = container
          .read(notificationChannelProvider(_screenId))
          .single
          .id;

      manager.showVolume(volume: 0.6, muted: false);

      final notifications = container.read(
        notificationChannelProvider(_screenId),
      );
      expect(notifications, hasLength(1));
      expect(notifications.single.id, firstId);
      expect(notifications.single.dbusNotification.hints.value, 60);
    });

    test('shows separate popups for volume and brightness', () async {
      container
          .read(systemNotificationManagerProvider.notifier)
          .showVolume(volume: 0.5, muted: false);

      events.add(
        PlatformEvent.brightnessChanged(
          method: 'brightness_changed',
          message: BrightnessChangedMessage(fraction: 0.3),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final notifications = container.read(
        notificationChannelProvider(_screenId),
      );
      expect(notifications, hasLength(2));
      expect(
        notifications.map((n) => n.dbusNotification.hints.category),
        containsAll([systemVolumeCategory, systemBrightnessCategory]),
      );
    });
  });

  testWidgets('dismissing a system popup removes it from its channel', (
    tester,
  ) async {
    const channel = 'screen-1';
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final channelSub = container.listen(
      notificationChannelProvider(channel),
      (_, _) {},
    );
    addTearDown(channelSub.close);
    container
        .read(notificationChannelProvider(channel).notifier)
        .add(_systemNotification(-1));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: NotificationArea(channel: channel, child: SizedBox()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(MdiIcons.close), findsOneWidget);
    await tester.tap(find.byIcon(MdiIcons.close));
    await tester.pumpAndSettle();

    expect(container.read(notificationChannelProvider(channel)), isEmpty);
  });
}
