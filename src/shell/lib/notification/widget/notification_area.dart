import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/notification/provider/notification_channel.dart';
import 'package:shell/notification/provider/notification_manager.dart';
import 'package:shell/notification/widget/notification.dart';
import 'package:shell/theme/provider/theme.dart';

/// Where the popup is anchored relative to its child.
enum NotificationAnchor {
  /// To the right of the child (e.g. a workspace button).
  right,

  /// Below the child (e.g. a tileable panel button).
  below,
}

/// Shows the notifications of [channel] as an overlay anchored to [child].
class NotificationArea extends HookConsumerWidget {
  /// Const constructor.
  const NotificationArea({
    required this.channel,
    required this.child,
    this.anchor = NotificationAnchor.right,
    this.offset = Offset.zero,
    this.maxWidth = 360,
    super.key,
  });

  /// The channel whose notifications are displayed.
  final String channel;

  /// The widget the popup is anchored to.
  final Widget child;

  /// The side of [child] the popup is anchored to.
  final NotificationAnchor anchor;

  /// Extra offset applied to the popup.
  final Offset offset;

  /// Maximum popup width.
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationList = ref.watch(notificationChannelProvider(channel));
    final controller = useMemoized(OverlayPortalController.new);
    final link = useMemoized(LayerLink.new);
    useEffect(() {
      if (notificationList.isEmpty && controller.isShowing) {
        WidgetsBinding.instance.addPostFrameCallback((d) => controller.hide());
      }
      if (notificationList.isNotEmpty && !controller.isShowing) {
        WidgetsBinding.instance.addPostFrameCallback((d) => controller.show());
      }
      return null;
    }, [notificationList]);

    // The popup's top-left corner is placed next to the target.
    final (targetAnchor, followerAnchor) = switch (anchor) {
      NotificationAnchor.right => (Alignment.topRight, Alignment.topLeft),
      NotificationAnchor.below => (Alignment.bottomLeft, Alignment.topLeft),
    };

    // Only the popup corner nearest the target stays square, so the popup reads
    // as an arrow pointing at it.
    final borderRadius = _popupBorderRadius(followerAnchor);

    return CompositedTransformTarget(
      link: link,
      child: OverlayPortal(
        controller: controller,
        overlayChildBuilder: (context) {
          return Positioned(
            left: 0,
            top: 0,
            child: CompositedTransformFollower(
              link: link,
              targetAnchor: targetAnchor,
              followerAnchor: followerAnchor,
              offset: offset,
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 16,
                    children: [
                      for (final notification in notificationList)
                        Card(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: borderRadius,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          child: NotificationWidget(
                            notification: notification,
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
                                  .dismissNotification(notification.id);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        child: child,
      ),
    );
  }
}

/// Rounds every corner except the one at [attach], which stays square.
BorderRadius _popupBorderRadius(Alignment attach) {
  const round = Radius.circular(surfaceRadius);
  return BorderRadius.only(
    topLeft: attach == Alignment.topLeft ? Radius.zero : round,
    topRight: attach == Alignment.topRight ? Radius.zero : round,
    bottomLeft: attach == Alignment.bottomLeft ? Radius.zero : round,
    bottomRight: attach == Alignment.bottomRight ? Radius.zero : round,
  );
}
