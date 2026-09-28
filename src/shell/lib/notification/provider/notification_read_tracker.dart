import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/notification/model/notification_target.dart';
import 'package:shell/notification/provider/notification_channel.dart';
import 'package:shell/notification/provider/notification_manager.dart';
import 'package:shell/notification/provider/notification_routing.dart';
import 'package:shell/screen/provider/focused_screen.dart';

part 'notification_read_tracker.g.dart';

/// Maintains the unread state as the notification routes change.
///
/// Popups are one-shot: they are pushed once by [NotificationManager] when the
/// notification is received and are never re-added here. A tile popup lives
/// inside its workspace overlay, so leaving the workspace clips it away instead
/// of tearing it down. This provider only marks notifications read (clearing
/// their popups) once their workspace or tile becomes displayed.
///
/// Keeping this in a dedicated provider avoids a cycle between the manager and
/// the routing provider (the manager persists the read flag, routing only
/// observes it).
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

      final (markRead, workspaceId, windowId) = switch (route) {
        DisplayedNotificationTarget(
          :final workspaceId,
          :final windowId,
        ) =>
          (true, workspaceId, windowId),
        EphemeralDisplayedNotificationTarget() => (true, null, null),
        TileNotificationTarget(:final workspaceId, :final windowId) => (
            // The workspace just became displayed while its tile stays hidden:
            // the workspace button dot has been seen, clear it.
            previousRoute is WorkspaceNotificationTarget &&
                previousRoute.workspaceId == workspaceId,
            workspaceId,
            windowId,
          ),
        WorkspaceNotificationTarget() ||
        UnresolvedNotificationTarget() =>
          (false, null, null),
      };
      if (!markRead) {
        continue;
      }
      if (workspaceId != null) {
        _removeFromChannel(
          ref,
          workspaceNotificationChannel(workspaceId),
          notification.id,
        );
      }
      if (windowId != null) {
        _removeFromChannel(
          ref,
          windowNotificationChannel(windowId),
          notification.id,
        );
      }
      if (route is EphemeralDisplayedNotificationTarget) {
        // The ephemeral window is visible in the overview: hide its default
        // popup if it is still on screen.
        final focusedScreenId = ref.read(focusedScreenProvider);
        if (focusedScreenId != null) {
          _removeFromChannel(ref, focusedScreenId, notification.id);
        }
      }
      ref.read(notificationManagerProvider.notifier).markRead(notification.id);
    }
  });
  return true;
}

void _removeFromChannel(Ref ref, String channel, int id) {
  final current = ref.read(notificationChannelProvider(channel));
  if (current.any((element) => element.id == id)) {
    ref.read(notificationChannelProvider(channel).notifier).remove(id);
  }
}
