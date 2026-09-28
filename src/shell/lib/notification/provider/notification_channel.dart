import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/notification/model/notification.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'notification_channel.g.dart';

/// Fallback popup duration used when the D-Bus sender passes `-1` as
/// `expireTimeout` (server decides).
const defaultNotificationPopupDuration = Duration(seconds: 8);

/// Popup channel name for a workspace button.
String workspaceNotificationChannel(WorkspaceId workspaceId) =>
    'workspace:$workspaceId';

/// Popup channel name for a tileable panel button.
String windowNotificationChannel(PersistentWindowId windowId) =>
    'window:${windowId.uuid}';

/// Converts a D-Bus `expireTimeout` (milliseconds) to a popup duration.
///
/// - `-1` lets the server decide ([defaultNotificationPopupDuration]).
/// - `0` means the notification never expires on its own (`null`).
Duration? notificationPopupTimeout(int expireTimeoutMs) {
  if (expireTimeoutMs == 0) {
    return null;
  }
  if (expireTimeoutMs < 0) {
    return defaultNotificationPopupDuration;
  }
  return Duration(milliseconds: expireTimeoutMs);
}

/// A Notification channel is a list of notifications for a specific name
/// It can be used to group notification for screens or specific windows
@riverpod
class NotificationChannel extends _$NotificationChannel {
  @override
  ISet<Notification> build(String channelName) {
    return <Notification>{}.lock;
  }

  void add(Notification notification, {Duration? timeout}) {
    state = state.add(notification);
    if (timeout != null) {
      Timer(timeout, () {
        remove(notification.id);
      });
    }
  }

  void remove(int id) {
    state = state.removeWhere((notification) => notification.id == id);
  }

  void clear() {
    state = <Notification>{}.lock;
  }
}
