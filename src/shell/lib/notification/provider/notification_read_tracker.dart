import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/notification/model/notification_close_reason.dart';
import 'package:shell/notification/model/notification_target.dart';
import 'package:shell/notification/provider/notification_manager.dart';
import 'package:shell/notification/provider/notification_routing.dart';

part 'notification_read_tracker.g.dart';

/// Maintains the unread state as the notification routes change.
///
/// Popups are one-shot: they are pushed once by [NotificationManager] when the
/// notification is received and are never re-added here. A tile popup lives
/// inside its workspace overlay, so leaving the workspace clips it away instead
/// of tearing it down. Once a notification's workspace or tile becomes
/// displayed it has been seen: its dot is cleared and its live popup is closed
/// (emitting `NotificationClosed`).
///
/// Keeping this in a dedicated provider avoids a cycle between the manager and
/// the routing provider (the manager persists the state, routing only observes
/// it).
@Riverpod(keepAlive: true)
bool notificationReadTracker(Ref ref) {
  ref.listen(notificationRoutesProvider, (previous, next) {
    final manager = ref.read(notificationManagerProvider);
    for (final entry in next.entries) {
      final notification = manager.notificationMap[entry.key];
      if (notification == null || notification.isRead) {
        continue;
      }
      final route = entry.value;
      final previousRoute = previous?[entry.key];

      final seen = switch (route) {
        DisplayedNotificationTarget() => true,
        EphemeralDisplayedNotificationTarget() => true,
        TileNotificationTarget(:final workspaceId) =>
          // The workspace just became displayed while its tile stays hidden:
          // the workspace button dot has been seen, clear it.
          previousRoute is WorkspaceNotificationTarget &&
              previousRoute.workspaceId == workspaceId,
        WorkspaceNotificationTarget() ||
        UnresolvedNotificationTarget() => false,
      };
      if (!seen) {
        continue;
      }
      // Close (idempotently) and mark read. A notification already closed by
      // expiry still needs its dot cleared here.
      ref
          .read(notificationManagerProvider.notifier)
          .closeNotification(
            notification.id,
            reason: NotificationCloseReason.dismissed,
            markRead: true,
          );
    }
  });
  return true;
}
