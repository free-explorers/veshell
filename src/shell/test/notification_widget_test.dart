import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Notification;
import 'package:shell/notification/model/dbus_notification.serializable.dart';
import 'package:shell/notification/model/notification.serializable.dart';
import 'package:shell/notification/model/notification_hints.serializable.dart';
import 'package:shell/notification/widget/notification.dart';

Notification _notification({List<String> actions = const []}) => Notification(
  id: 1,
  appId: null,
  dbusNotification: DbusNotification(
    pid: null,
    appName: 'App',
    replacesId: 0,
    appIcon: 'file:///nonexistent',
    summary: 'Summary',
    body: 'Body',
    actions: actions,
    hints: const NotificationHints(),
    expireTimeout: -1,
  ),
  createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Material(child: child)),
);

void main() {
  testWidgets('tapping the body opens the window', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      _wrap(
        NotificationWidget(
          notification: _notification(actions: const ['open', 'Open']),
          onOpen: () => opened = true,
          onAction: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Summary'));

    expect(opened, isTrue);
  });

  testWidgets('body tap opens; the default action is left to the caller',
      (tester) async {
    var opened = false;
    String? invoked;
    await tester.pumpWidget(
      _wrap(
        NotificationWidget(
          notification: _notification(
            actions: const ['default', '', 'open', 'Open'],
          ),
          onOpen: () => opened = true,
          onAction: (key) => invoked = key,
        ),
      ),
    );

    await tester.tap(find.text('Summary'));

    expect(opened, isTrue);
    expect(invoked, isNull);
  });

  testWidgets('action buttons invoke their action', (tester) async {
    String? invoked;
    await tester.pumpWidget(
      _wrap(
        NotificationWidget(
          notification: _notification(actions: const ['open', 'Open']),
          onOpen: () {},
          onAction: (key) => invoked = key,
        ),
      ),
    );

    await tester.tap(find.text('Open'));

    expect(invoked, 'open');
  });
}
