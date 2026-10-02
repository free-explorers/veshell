import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart' hide Notification;
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_manager.dart';
import 'package:shell/notification/model/notification.serializable.dart';
import 'package:shell/notification/provider/notification_list.dart';
import 'package:shell/overview/helm/notification_panel/widget/notification_panel.dart';

void main() {
  testWidgets('an empty notification list shows the empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationListProvider.overrideWithValue(
            const IListConst<Notification>([]),
          ),
          metaWindowManagerProvider.overrideWithValue(
            const ISetConst<MetaWindowId>({}),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: NotificationPanel())),
      ),
    );

    expect(find.text('No activity yet'), findsOneWidget);
    expect(
      find.text('Your notification history is currently empty'),
      findsOneWidget,
    );
    expect(find.byIcon(MdiIcons.bullhornVariantOutline), findsOneWidget);
  });
}
