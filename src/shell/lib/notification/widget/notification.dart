import 'dart:io';
import 'dart:typed_data';

import 'package:duration/duration.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/notification/model/notification.serializable.dart' as Me;
import 'package:shell/notification/model/notification_action.dart';

class NotificationWidget extends StatelessWidget {
  const NotificationWidget({
    required this.notification,
    this.onClose,
    this.onAction,
    super.key,
  });

  final Me.Notification notification;
  final VoidCallback? onClose;

  /// Called with the action key when the user activates an action.
  ///
  /// The implicit `default` action is triggered by tapping the body. Actions
  /// are hidden once the notification has been closed, since its sender is no
  /// longer waiting for them.
  final void Function(String actionKey)? onAction;

  @override
  Widget build(BuildContext context) {
    final actions = parseNotificationActions(
      notification.dbusNotification.actions,
    );
    final canAct = onAction != null && !notification.isClosed;
    final defaultAction = canAct ? defaultNotificationAction(actions) : null;
    final buttons = canAct
        ? actions.where((action) => !action.isDefault).toList()
        : const <NotificationAction>[];

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (notification.appId != null)
                SizedBox.square(
                  dimension: 16,
                  child: AppIconById(id: notification.appId),
                )
              else if (File(
                Uri.parse(notification.dbusNotification.appIcon).toFilePath(),
              ).existsSync())
                SizedBox.square(
                  dimension: 16,
                  child: Image.file(
                    File(
                      Uri.parse(
                        notification.dbusNotification.appIcon,
                      ).toFilePath(),
                    ),
                  ),
                )
              else
                const Icon(MdiIcons.bell, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: notification.dbusNotification.appName,
                    children: [
                      TextSpan(
                        text:
                            ' • ${DateTime.now().difference(notification.createdAt).pretty(abbreviated: true, maxUnits: 1)}',
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Text(
            notification.dbusNotification.summary,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(notification.dbusNotification.body),
          if (notification.dbusNotification.hints.imageData != null)
            SizedBox(
              width: 100,
              height: 100,
              child: Image.memory(
                Uint8List.fromList(
                  notification.dbusNotification.hints.imageData!,
                ),
              ),
            ),
          if (buttons.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: [
                for (final action in buttons)
                  TextButton(
                    onPressed: () => onAction!(action.key),
                    child: Text(action.label),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    return Stack(
      children: [
        if (defaultAction != null)
          InkWell(onTap: () => onAction!(defaultAction.key), child: content)
        else
          content,
        Positioned(
          right: 8,
          top: 9,
          child: IconButton(
            style: IconButton.styleFrom(padding: EdgeInsets.zero),
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: const Icon(MdiIcons.close),
            onPressed: onClose,
          ),
        ),
      ],
    );
  }
}
