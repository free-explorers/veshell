import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/meta_window/provider/meta_window_manager.dart';
import 'package:shell/notification/provider/notification_list.dart';
import 'package:shell/notification/provider/notification_manager.dart';
import 'package:shell/notification/provider/notification_routing.dart';
import 'package:shell/notification/widget/notification.dart';

class NotificationPanel extends HookConsumerWidget {
  const NotificationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationList = ref.watch(notificationListProvider);
    final openMetaWindows = ref.watch(metaWindowManagerProvider);
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  MdiIcons.bullhornVariant,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    context.l10n.notifications,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  tooltip: context.l10n.clearAll,
                  onPressed: notificationList.isEmpty
                      ? null
                      : () => ref
                            .read(notificationManagerProvider.notifier)
                            .dismissAllNotifications(),
                  icon: const Icon(MdiIcons.notificationClearAll),
                  style: IconButton.styleFrom(padding: const EdgeInsets.all(4)),
                ),
              ],
            ),
          ),
          Expanded(
            child: notificationList.isEmpty
                ? const _EmptyNotifications()
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notification = notificationList[index];
                      // An entry whose window is gone is kept for history:
                      // dim it so it reads differently from a live one.
                      final dimmed = !isNotificationLive(
                        notification,
                        openMetaWindows,
                      );
                      return Card(
                        margin: EdgeInsets.zero,
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: NotificationWidget(
                          notification: notification,
                          dimmed: dimmed,
                          onAction: (actionKey) {
                            ref
                                .read(notificationManagerProvider.notifier)
                                .invokeAction(notification.id, actionKey);
                          },
                          onOpen: () {
                            ref
                                .read(notificationManagerProvider.notifier)
                                .openNotification(notification.id);
                          },
                          onClose: () {
                            ref
                                .read(notificationManagerProvider.notifier)
                                .dismissAndRemoveNotification(notification.id);
                          },
                        ),
                      );
                    },
                    itemCount: notificationList.length,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder shown while there is nothing to list, so the panel reads as
/// intentionally empty instead of looking like content failed to load.
class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: const Alignment(0, -0.5),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              MdiIcons.bullhornVariantOutline,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.noActivityYet,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.notificationHistoryEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
