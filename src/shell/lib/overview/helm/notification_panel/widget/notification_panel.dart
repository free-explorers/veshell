import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/provider/meta_window_manager.dart';
import 'package:shell/notification/provider/notification_list.dart';
import 'package:shell/notification/provider/notification_manager.dart';
import 'package:shell/notification/provider/notification_routing.dart';
import 'package:shell/notification/widget/notification.dart';

class NotificationPanel extends HookConsumerWidget {
  const NotificationPanel({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationList = ref.watch(notificationListProvider);
    final openMetaWindows = ref.watch(metaWindowManagerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    separatorBuilder: (context, index) => const SizedBox(
                      height: 8,
                    ),
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
          ),
        ),
      ],
    );
  }
}
