import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/notification/model/dbus_notification.serializable.dart';
import 'package:shell/notification/model/notification.serializable.dart';
import 'package:shell/notification/model/notification_hints.serializable.dart';
import 'package:shell/notification/provider/notification_channel.dart';

const _channel = 'test-channel';

Notification _notification(int id) => Notification(
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
);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    // Keep the auto-dispose channel alive for the duration of the test.
    container.listen(notificationChannelProvider(_channel), (_, _) {});
  });

  test('expires a notification and invokes onExpire', () async {
    var expired = false;
    container
        .read(notificationChannelProvider(_channel).notifier)
        .add(
          _notification(1),
          timeout: const Duration(milliseconds: 10),
          onExpire: () => expired = true,
        );

    expect(container.read(notificationChannelProvider(_channel)), hasLength(1));

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(expired, isTrue);
    expect(container.read(notificationChannelProvider(_channel)), isEmpty);
  });

  test('removing before the timeout cancels expiry', () async {
    var expired = false;
    container.read(notificationChannelProvider(_channel).notifier)
      ..add(
        _notification(1),
        timeout: const Duration(milliseconds: 10),
        onExpire: () => expired = true,
      )
      ..remove(1);

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(expired, isFalse);
    expect(container.read(notificationChannelProvider(_channel)), isEmpty);
  });

  test('re-adding the same id replaces the entry', () {
    container.read(notificationChannelProvider(_channel).notifier)
      ..add(_notification(1), timeout: const Duration(seconds: 10))
      ..add(_notification(1), timeout: const Duration(seconds: 10));

    expect(container.read(notificationChannelProvider(_channel)), hasLength(1));
  });

  group('without a listener', () {
    // A keepAlive manager adds popups to channels whose notification area may
    // not be mounted (hidden workspace, closed overview).
    late ProviderContainer unwatched;

    setUp(() {
      unwatched = ProviderContainer();
      addTearDown(unwatched.dispose);
    });

    test('a pending popup survives until it expires', () async {
      var expired = false;
      unwatched
          .read(notificationChannelProvider(_channel).notifier)
          .add(
            _notification(1),
            timeout: const Duration(milliseconds: 30),
            onExpire: () => expired = true,
          );

      // Auto-dispose runs asynchronously once the provider has no listener.
      await Future<void>.delayed(Duration.zero);
      expect(
        unwatched.read(notificationChannelProvider(_channel)),
        hasLength(1),
      );

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(expired, isTrue);
    });

    test('an emptied channel is released', () async {
      unwatched.read(notificationChannelProvider(_channel).notifier)
        ..add(_notification(1))
        ..remove(1);

      await Future<void>.delayed(Duration.zero);
      expect(unwatched.exists(notificationChannelProvider(_channel)), isFalse);
    });
  });
}
