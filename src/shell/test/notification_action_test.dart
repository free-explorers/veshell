import 'package:flutter_test/flutter_test.dart';
import 'package:shell/notification/model/notification_action.dart';
import 'package:shell/notification/model/notification_close_reason.dart';

void main() {
  group('parseNotificationActions', () {
    test('pairs keys and labels', () {
      final actions = parseNotificationActions([
        'open',
        'Open',
        'dismiss',
        'Dismiss',
      ]);

      expect(actions, [
        const NotificationAction(key: 'open', label: 'Open'),
        const NotificationAction(key: 'dismiss', label: 'Dismiss'),
      ]);
    });

    test('keeps the default action and flags it', () {
      final actions = parseNotificationActions(['default', '', 'open', 'Open']);

      expect(defaultNotificationAction(actions)?.key, 'default');
      expect(defaultNotificationAction(actions)?.isDefault, isTrue);
    });

    test('ignores a trailing key without a label', () {
      expect(parseNotificationActions(['open', 'Open', 'dangling']), [
        const NotificationAction(key: 'open', label: 'Open'),
      ]);
    });

    test('handles an empty action list', () {
      expect(parseNotificationActions(const []), isEmpty);
      expect(defaultNotificationAction(const []), isNull);
    });
  });

  test('close reasons match the spec values', () {
    expect(NotificationCloseReason.expired.value, 1);
    expect(NotificationCloseReason.dismissed.value, 2);
    expect(NotificationCloseReason.closedByCall.value, 3);
  });
}
