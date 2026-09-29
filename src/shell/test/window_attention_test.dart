import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/notification/model/dbus_notification.serializable.dart';
import 'package:shell/notification/model/notification.serializable.dart';
import 'package:shell/notification/model/notification_hints.serializable.dart';
import 'package:shell/notification/model/notification_manager_state.serializable.dart';
import 'package:shell/notification/provider/notification_list.dart';
import 'package:shell/notification/provider/notification_manager.dart';
import 'package:shell/notification/provider/notification_routing.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';

Notification _notification(
  int id, {
  bool synthetic = false,
  String? targetMetaWindowId,
}) => Notification(
  id: id,
  appId: null,
  dbusNotification: const DbusNotification(
    pid: null,
    appName: 'App',
    replacesId: 0,
    appIcon: '',
    summary: 'Summary',
    body: 'Body',
    actions: [],
    hints: NotificationHints(),
    expireTimeout: -1,
  ),
  createdAt: DateTime(2026),
  targetMetaWindowId: targetMetaWindowId,
  isSynthetic: synthetic,
);

void main() {
  group('window attention platform events', () {
    test('decodes an activation request with its meta window id', () {
      final event = PlatformEvent.fromJson(const {
        'method': 'window_activation_requested',
        'message': {'metaWindowId': 'meta-1'},
      });

      expect(event, isA<WindowActivationRequestedEvent>());
      expect(
        (event as WindowActivationRequestedEvent).message.metaWindowId,
        'meta-1',
      );
    });

    test('decodes a request with its meta window id', () {
      final event = PlatformEvent.fromJson(const {
        'method': 'window_attention_requested',
        'message': {'metaWindowId': 'meta-1'},
      });

      expect(event, isA<WindowAttentionRequestedEvent>());
      expect(
        (event as WindowAttentionRequestedEvent).message.metaWindowId,
        'meta-1',
      );
    });

    test('decodes a release with its meta window id', () {
      final event = PlatformEvent.fromJson(const {
        'method': 'window_attention_released',
        'message': {'metaWindowId': 'meta-1'},
      });

      expect(event, isA<WindowAttentionReleasedEvent>());
      expect(
        (event as WindowAttentionReleasedEvent).message.metaWindowId,
        'meta-1',
      );
    });
  });

  test('a synthesized notification round-trips and stays synthetic', () {
    final notification = Notification(
      id: 7,
      appId: 'org.example.App',
      dbusNotification: const DbusNotification(
        pid: 42,
        appName: 'Example',
        replacesId: 0,
        appIcon: '',
        summary: 'Example requests attention',
        // The CTA body is omitted: the model defaults it to empty.
        actions: [],
        hints: NotificationHints(),
        expireTimeout: -1,
      ),
      createdAt: DateTime.utc(2026),
      isSynthetic: true,
    );

    final decoded = Notification.fromJson(notification.toJson());

    expect(decoded.isSynthetic, isTrue);
    expect(decoded.dbusNotification.summary, 'Example requests attention');
    expect(decoded.dbusNotification.body, isEmpty);
  });

  test('the notification center excludes synthesized attention entries', () {
    final container = ProviderContainer(
      overrides: [
        notificationManagerProvider.overrideWithValue(
          NotificationManagerState(
            notificationMap: {
              1: _notification(1),
              2: _notification(2, synthetic: true),
            }.lock,
            lastIndex: 2,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final list = container.read(notificationListProvider);

    expect(list.map((notification) => notification.id), [1]);
  });

  group('isNotificationLive', () {
    test('a notification with no MetaWindow stays live', () {
      expect(isNotificationLive(_notification(1), <String>{}.lock), isTrue);
    });

    test('a notification is live while its exact MetaWindow is open', () {
      final notification = _notification(1, targetMetaWindowId: 'meta-1');

      expect(isNotificationLive(notification, {'meta-1'}.lock), isTrue);
    });

    test('a notification is history once its MetaWindow is gone', () {
      final notification = _notification(1, targetMetaWindowId: 'meta-1');

      expect(isNotificationLive(notification, {'meta-2'}.lock), isFalse);
    });
  });
}
