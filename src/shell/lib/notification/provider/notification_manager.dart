import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/provider/pid_to_meta_window_id.dart';
import 'package:shell/notification/model/dbus_notification.serializable.dart';
import 'package:shell/notification/model/dbus_notification_server.dart';
import 'package:shell/notification/model/notification.serializable.dart';
import 'package:shell/notification/model/notification_action.dart';
import 'package:shell/notification/model/notification_close_reason.dart';
import 'package:shell/notification/model/notification_manager_state.serializable.dart';
import 'package:shell/notification/model/notification_target.dart';
import 'package:shell/notification/provider/notification_channel.dart';
import 'package:shell/notification/provider/notification_routing.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/window/provider/window_navigation.dart';
import 'package:shell/workspace/provider/window_workspace_map.dart';

part 'notification_manager.g.dart';

@riverpod
@JsonPersist()
class NotificationManager extends _$NotificationManager {
  DbusNotificationServer? _server;

  /// The popup channel each live notification was pushed to, so its popup can
  /// be torn down even after the notification's route has changed.
  ///
  /// Runtime-only: never persisted, since channels are rebuilt from scratch.
  final _popupChannels = <int, String>{};

  @override
  NotificationManagerState build() {
    persist(
      ref.watch(persistentStorageStateProvider).requireValue,
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    );
    unawaited(initServer());
    return stateOrNull ??
        NotificationManagerState(
          notificationMap: <int, Notification>{}.lock,
          lastIndex: 0,
        );
  }

  Future<void> initServer() async {
    final dbusClient = DBusClient.session();
    final requestNameReply = await dbusClient.requestName(
      'org.freedesktop.Notifications',
    );
    if (requestNameReply == DBusRequestNameReply.primaryOwner) {
      print('Successfully registered as org.freedesktop.Notifications');
    } else {
      print('Failed to register name: $requestNameReply');
    }
    final server = DbusNotificationServer(
      onNewNotification: _onNewNotification,
      onCloseNotification: (id) => closeNotification(
        id,
        reason: NotificationCloseReason.closedByCall,
        removeFromHistory: true,
      ),
    );
    _server = server;
    await dbusClient.registerObject(server);
  }

  int _onNewNotification(DbusNotification newNotification) {
    final replacesId = newNotification.replacesId;
    if (replacesId != 0) {
      final existing = state.notificationMap[replacesId];
      // A closed id is no longer known to the sender: treat it as new.
      if (existing != null && !existing.isClosed) {
        return _replaceNotification(replacesId, newNotification);
      }
    }
    return _addNotification(newNotification);
  }

  int _addNotification(DbusNotification newNotification) {
    final newId = state.lastIndex + 1;
    final notification = _buildNotification(newId, newNotification);
    state = state.copyWith(
      notificationMap: state.notificationMap.add(newId, notification),
      lastIndex: newId,
    );
    _showPopup(notification);
    return newId;
  }

  int _replaceNotification(int id, DbusNotification newNotification) {
    // Drop the replaced popup and its expiry timer before re-routing.
    _clearPopup(id);
    final notification = _buildNotification(id, newNotification);
    state = state.copyWith(
      notificationMap: state.notificationMap.add(id, notification),
    );
    _showPopup(notification);
    return id;
  }

  Notification _buildNotification(int id, DbusNotification dbusNotification) {
    return Notification(
      id: id,
      appId: _resolveAppId(dbusNotification),
      dbusNotification: dbusNotification,
      createdAt: DateTime.now(),
      targetWindowId: resolveNotificationTargetWindow(ref, dbusNotification),
    );
  }

  String? _resolveAppId(DbusNotification notification) {
    final hint = notification.hints.desktopEntry;
    if (hint != null) {
      return hint;
    }
    final pid = notification.pid;
    if (pid == null) {
      return null;
    }
    final metaWindowId = ref.read(pidToMetaWindowIdProvider(pid));
    if (metaWindowId == null) {
      return null;
    }
    return ref.read(metaWindowStateProvider(metaWindowId)).appId;
  }

  /// Pushes the transient popup to the channel matching the notification's
  /// target. Displayed notifications only live in the persisted list.
  void _showPopup(Notification notification) {
    final target = routeForWindow(
      notification.targetWindowId,
      windowWorkspaceMap: ref.read(windowWorkspaceMapProvider),
      focusedWorkspaceId: ref.read(focusedWorkspaceIdProvider),
      displayedWindowIds: ref.read(displayedWindowIdsProvider),
      displayedEphemeralWindowIds: ref.read(
        displayedEphemeralWindowIdsProvider,
      ),
    );
    final channel = _popupChannelFor(target);
    if (channel == null) {
      return;
    }
    _popupChannels[notification.id] = channel;
    ref
        .read(notificationChannelProvider(channel).notifier)
        .add(
          notification,
          timeout: notificationPopupTimeout(
            notification.dbusNotification.expireTimeout,
          ),
          onExpire: () => unawaited(
            _closeNotification(
              notification.id,
              reason: NotificationCloseReason.expired,
            ),
          ),
        );
  }

  String? _popupChannelFor(NotificationTarget target) {
    return switch (target) {
      DisplayedNotificationTarget() ||
      EphemeralDisplayedNotificationTarget() => null,
      WorkspaceNotificationTarget(:final workspaceId) =>
        workspaceNotificationChannel(workspaceId),
      TileNotificationTarget(:final windowId) => windowNotificationChannel(
        windowId,
      ),
      UnresolvedNotificationTarget() => ref.read(focusedScreenProvider),
    };
  }

  /// Emits `ActionInvoked` for [id] and closes the notification unless its
  /// sender asked for it to stay resident.
  void invokeAction(int id, String actionKey) {
    unawaited(_invokeAction(id, actionKey));
  }

  /// Brings the window that sent notification [id] into view and marks it read.
  void openNotification(int id) {
    unawaited(_openNotification(id));
  }

  /// Emits `NotificationClosed` (once) and tears down the live popup.
  ///
  /// [reason] is the spec reason. Set [removeFromHistory] to also drop the
  /// entry from the persisted list, and [markRead] to clear its unread dot.
  void closeNotification(
    int id, {
    required NotificationCloseReason reason,
    bool removeFromHistory = false,
    bool markRead = false,
  }) {
    unawaited(
      _closeNotification(
        id,
        reason: reason,
        removeFromHistory: removeFromHistory,
        markRead: markRead,
      ),
    );
  }

  /// Dismisses the popup of [id], keeping it in the persisted history.
  void dismissNotification(int id) {
    closeNotification(
      id,
      reason: NotificationCloseReason.dismissed,
      markRead: true,
    );
  }

  /// Removes [id] from the persisted history, closing it first if still live.
  void dismissAndRemoveNotification(int id) {
    closeNotification(
      id,
      reason: NotificationCloseReason.dismissed,
      markRead: true,
      removeFromHistory: true,
    );
  }

  Future<void> _openNotification(int id) async {
    final notification = state.notificationMap[id];
    if (notification == null) {
      return;
    }
    // The target is resolved at reception; re-resolve in case it could not be
    // mapped yet when the notification arrived, then fall back to the app id.
    final appId = notification.appId;
    final target = notification.targetWindowId ??
        resolveNotificationTargetWindow(ref, notification.dbusNotification) ??
        (appId == null ? null : persistentWindowForAppId(ref, appId));

    // Keep the spec's default action: alongside revealing the window, the
    // sender is told the notification was activated.
    final defaultAction = defaultNotificationAction(
      parseNotificationActions(notification.dbusNotification.actions),
    );
    if (defaultAction != null && !notification.isClosed) {
      await _emitActionInvoked(id, defaultAction.key);
    }

    if (target != null) {
      navigationLog.info('Opening notification $id -> $target');
      bringWindowIntoView(ref, target);
    } else {
      navigationLog.info('Notification $id has no target window to open');
    }

    if (notification.dbusNotification.hints.resident ?? false) {
      // A resident notification stays on screen until explicitly closed.
      _setRead(id);
      return;
    }
    await _closeNotification(
      id,
      reason: NotificationCloseReason.dismissed,
      markRead: true,
    );
  }

  Future<void> _invokeAction(int id, String actionKey) async {
    final notification = state.notificationMap[id];
    if (notification == null || notification.isClosed) {
      return;
    }
    _setRead(id);
    await _emitActionInvoked(id, actionKey);
    final resident = notification.dbusNotification.hints.resident ?? false;
    if (!resident) {
      await _closeNotification(
        id,
        reason: NotificationCloseReason.dismissed,
        markRead: true,
      );
    }
  }

  Future<void> _closeNotification(
    int id, {
    required NotificationCloseReason reason,
    bool removeFromHistory = false,
    bool markRead = false,
  }) async {
    final notification = state.notificationMap[id];
    if (notification == null) {
      return;
    }
    final shouldSignal = !notification.isClosed;
    // Update state synchronously, before awaiting the signal, so re-entrant
    // route listeners observe the new read/closed flags and converge instead
    // of signaling the same notification twice.
    var notificationMap = state.notificationMap.add(
      id,
      notification.copyWith(
        isClosed: true,
        isRead: notification.isRead || markRead,
      ),
    );
    if (removeFromHistory) {
      notificationMap = notificationMap.remove(id);
    }
    state = state.copyWith(notificationMap: notificationMap);
    _clearPopup(id);
    if (shouldSignal) {
      await _emitNotificationClosed(id, reason.value);
    }
  }

  void _setRead(int id) {
    final notification = state.notificationMap[id];
    if (notification == null || notification.isRead) {
      return;
    }
    state = state.copyWith(
      notificationMap: state.notificationMap.add(
        id,
        notification.copyWith(isRead: true),
      ),
    );
  }

  void _clearPopup(int id) {
    final channel = _popupChannels.remove(id);
    if (channel == null) {
      return;
    }
    ref.read(notificationChannelProvider(channel).notifier).remove(id);
  }

  Future<void> _emitActionInvoked(int id, String actionKey) async {
    final server = _server;
    if (server == null) {
      return;
    }
    try {
      await server.emitActionInvoked(id, actionKey);
    } on Object catch (error) {
      print('Failed to emit ActionInvoked($id, $actionKey): $error');
    }
  }

  Future<void> _emitNotificationClosed(int id, int reason) async {
    final server = _server;
    if (server == null) {
      return;
    }
    try {
      await server.emitNotificationClosed(id, reason);
    } on Object catch (error) {
      print('Failed to emit NotificationClosed($id, $reason): $error');
    }
  }
}
