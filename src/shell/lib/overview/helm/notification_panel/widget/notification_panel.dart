import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/notification/provider/notification_list.dart';
import 'package:shell/overview/helm/notification_panel/widget/notification.dart';

class NotificationPanel extends HookConsumerWidget {
  const NotificationPanel({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationList = ref.watch(notificationListProvider);
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
                      return NotificationWidget(notification: notification);
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
