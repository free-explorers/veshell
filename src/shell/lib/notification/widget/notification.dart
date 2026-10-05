import 'dart:io';
import 'dart:typed_data';

import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/notification/model/notification.serializable.dart' as Me;
import 'package:shell/notification/model/notification_action.dart';
import 'package:shell/notification/model/system_notification_category.dart';
import 'package:shell/shared/util/relative_time.dart';

class NotificationWidget extends StatelessWidget {
  const NotificationWidget({
    required this.notification,
    this.onClose,
    this.onAction,
    this.onOpen,
    this.dimmed = false,
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

  /// Called when the body is tapped: brings the window that sent the
  /// notification into view. When set, it takes precedence over the `default`
  /// action, which is only invoked when no [onOpen] handler is provided.
  final VoidCallback? onOpen;

  /// Whether to render the notification as history: its window is gone, so it
  /// is kept only for the record. History entries are dimmed.
  final bool dimmed;

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
    // Bringing the window into view is the primary body action; the `default`
    // action is only a fallback when the caller does not open windows.
    final onBodyTap =
        onOpen ??
        (defaultAction != null ? () => onAction!(defaultAction.key) : null);
    // Localized so the relative age can be translated with the rest of the app.
    final age = formatRelativeTime(
      notification.createdAt,
      localeName: Localizations.localeOf(context).toString(),
    );

    // A system notification (volume, brightness, battery) has no desktop entry
    // to resolve an icon from; its category selects a Material Design glyph.
    final hints = notification.dbusNotification.hints;
    final systemIcon = switch (hints.category) {
      systemVolumeCategory => MdiIcons.volumeHigh,
      systemVolumeMutedCategory => MdiIcons.volumeOff,
      systemBrightnessCategory => MdiIcons.brightness6,
      systemBatteryCategory => MdiIcons.batteryAlert,
      _ => null,
    };
    final progressValue = hints.value;

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Row(
            children: [
              if (systemIcon != null)
                Icon(systemIcon, size: 16)
              else if (notification.appId != null)
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
                        text: ' • $age',
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
          if (notification.dbusNotification.body.isNotEmpty)
            Text(notification.dbusNotification.body),
          if (progressValue != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (progressValue / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
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
            const SizedBox(height: 4),
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

    final card = Stack(
      children: [
        if (onBodyTap != null)
          InkWell(onTap: onBodyTap, child: content)
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
    // History entries are dimmed so a still-open window's notification reads
    // as the actionable one.
    return dimmed ? Opacity(opacity: 0.5, child: card) : card;
  }
}
