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
  /// Pending expiry timers, keyed by notification id, so an explicit removal
  /// cancels the timer and never fires [add]'s `onExpire` afterwards.
  final _expiryTimers = <int, Timer>{};

  @override
  ISet<Notification> build(String channelName) {
    ref.onDispose(_cancelAllTimers);
    return <Notification>{}.lock;
  }

  /// Adds [notification], replacing any previous entry with the same id.
  ///
  /// When [timeout] is non-null the notification is removed after that delay
  /// and [onExpire] is invoked (used to emit `NotificationClosed`). A removal
  /// before the delay cancels both.
  void add(
    Notification notification, {
    Duration? timeout,
    void Function()? onExpire,
  }) {
    _cancelTimer(notification.id);
    state = state
        .removeWhere((existing) => existing.id == notification.id)
        .add(notification);
    if (timeout != null) {
      _expiryTimers[notification.id] = Timer(timeout, () {
        _expiryTimers.remove(notification.id);
        remove(notification.id);
        onExpire?.call();
      });
    }
  }

  void remove(int id) {
    _cancelTimer(id);
    state = state.removeWhere((notification) => notification.id == id);
  }

  void clear() {
    _cancelAllTimers();
    state = <Notification>{}.lock;
  }

  void _cancelTimer(int id) {
    _expiryTimers.remove(id)?.cancel();
  }

  void _cancelAllTimers() {
    for (final timer in _expiryTimers.values) {
      timer.cancel();
    }
    _expiryTimers.clear();
  }
}
