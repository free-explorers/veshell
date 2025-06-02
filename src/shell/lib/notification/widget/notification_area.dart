import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/notification/provider/notification_channel.dart';
import 'package:shell/notification/widget/notification.dart';

class NotificationArea extends HookConsumerWidget {
  const NotificationArea({
    required this.channel,
    required this.child,
    required this.offset,
    super.key,
  });
  final Widget child;
  final String channel;
  final Offset offset;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationList = ref.watch(notificationChannelProvider(channel));
    final controller = useMemoized(OverlayPortalController.new);
    useEffect(
      () {
        if (notificationList.isEmpty && controller.isShowing) {
          WidgetsBinding.instance
              .addPostFrameCallback((d) => controller.hide());
        }
        if (notificationList.isNotEmpty && !controller.isShowing) {
          WidgetsBinding.instance
              .addPostFrameCallback((d) => controller.show());
        }
        return null;
      },
      [notificationList],
    );
    return OverlayPortal(
      controller: controller,
      overlayChildBuilder: (context) {
        return Positioned(
          left: offset.dx,
          top: offset.dy,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              for (final notification in notificationList)
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: NotificationWidget(
                    notification: notification,
                    onClose: () => ref
                        .read(notificationChannelProvider(channel).notifier)
                        .remove(notification.id),
                  ),
                ),
            ],
          ),
        );
      },
      child: child,
    );
  }
}
