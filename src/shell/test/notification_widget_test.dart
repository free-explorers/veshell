import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Notification;
import 'package:shell/l10n/l10n.dart';
import 'package:shell/notification/model/dbus_notification.serializable.dart';
import 'package:shell/notification/model/notification.serializable.dart';
import 'package:shell/notification/model/notification_hints.serializable.dart';
import 'package:shell/notification/widget/notification.dart';

Notification _notification({
  List<String> actions = const [],
  String body = 'Body',
}) => Notification(
  id: 1,
  appId: null,
  dbusNotification: DbusNotification(
    pid: null,
    appName: 'App',
    replacesId: 0,
    appIcon: 'file:///nonexistent',
    summary: 'Summary',
    body: body,
    actions: actions,
    hints: const NotificationHints(),
    expireTimeout: -1,
  ),
  createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
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

  testWidgets('body tap opens; the default action is left to the caller', (
    tester,
  ) async {
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

  group('a long notification', () {
    final longBody = List.filled(40, 'word').join(' ');
    final expand = find.byKey(const ValueKey('notification-expand'));

    Future<void> pump(WidgetTester tester, String body) => tester.pumpWidget(
      _wrap(
        Center(
          child: SizedBox(
            width: 300,
            child: NotificationWidget(
              notification: _notification(body: body),
              onClose: () {},
            ),
          ),
        ),
      ),
    );

    testWidgets('is cut to a few lines until expanded', (tester) async {
      await pump(tester, longBody);
      final fade = find.byType(AnimatedCrossFade);
      CrossFadeState state() =>
          tester.widget<AnimatedCrossFade>(fade).crossFadeState;
      // Both versions of the text are built: one cut, one in full.
      final bodies = tester.widgetList<Text>(find.text(longBody)).toList();
      final collapsed = tester.getSize(fade).height;

      expect(expand, findsOneWidget);
      expect(state(), CrossFadeState.showFirst);
      expect(bodies.map((text) => text.maxLines), unorderedEquals([4, null]));
      expect(
        bodies.firstWhere((text) => text.maxLines == 4).overflow,
        TextOverflow.ellipsis,
      );

      await tester.tap(expand);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Halfway through, the text is still growing towards its full height.
      final halfway = tester.getSize(fade).height;
      expect(halfway, greaterThan(collapsed));

      await tester.pumpAndSettle();

      expect(state(), CrossFadeState.showSecond);
      expect(tester.getSize(fade).height, greaterThan(halfway));

      await tester.tap(expand);
      await tester.pumpAndSettle();

      expect(state(), CrossFadeState.showFirst);
      expect(tester.getSize(fade).height, collapsed);
    });

    testWidgets('a short one has nothing to expand', (tester) async {
      await pump(tester, 'Short');

      expect(expand, findsNothing);
      expect(tester.widget<Text>(find.text('Short')).maxLines, isNull);
    });
  });
}
