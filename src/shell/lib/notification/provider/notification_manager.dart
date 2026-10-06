import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_manager.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/provider/pid_to_meta_window_id.dart';
import 'package:shell/notification/model/dbus_notification.serializable.dart';
import 'package:shell/notification/model/notification.serializable.dart';
import 'package:shell/notification/model/notification_action.dart';
import 'package:shell/notification/model/notification_action_invoked/notification_action_invoked.serializable.dart';
import 'package:shell/notification/model/notification_activation_token/notification_activation_token.serializable.dart';
import 'package:shell/notification/model/notification_close_reason.dart';
import 'package:shell/notification/model/notification_closed/notification_closed.serializable.dart';
import 'package:shell/notification/model/notification_hints.serializable.dart';
import 'package:shell/notification/model/notification_manager_state.serializable.dart';
import 'package:shell/notification/model/notification_notify_result/notification_notify_result.serializable.dart';
import 'package:shell/notification/model/notification_ready/notification_ready.dart';
import 'package:shell/notification/model/notification_target.dart';
import 'package:shell/notification/provider/notification_channel.dart';
import 'package:shell/notification/provider/notification_routing.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/window/provider/window_navigation.dart';
import 'package:shell/workspace/provider/window_workspace_map.dart';

part 'notification_manager.g.dart';

@riverpod
@JsonPersist()
class NotificationManager extends _$NotificationManager {
  /// The popup channel each live notification was pushed to, so its popup can
  /// be torn down even after the notification's route has changed.
  ///
  /// Runtime-only: never persisted, since channels are rebuilt from scratch.
  final _popupChannels = <int, String>{};

  /// The live synthesized attention notification for each window that asked
  /// for attention, keyed by meta window id.
  ///
  /// Runtime-only: lets a repeated request replace nothing (no stacking) and
  /// lets an X11 `undemands_attention` drop the matching live notification.
  final _attentionNotificationByWindow = <MetaWindowId, int>{};

  @override
  NotificationManagerState build() {
    persist(
      ref.watch(persistentStorageStateProvider).requireValue,
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    );
    // The compositor owns the D-Bus surface and forwards accepted calls here;
    // the shell owns the state and answers with the assigned id.
    final subscription = ref
        .watch(platformManagerProvider)
        .listen(_onPlatformEvent);
    ref.onDispose(subscription.cancel);
    // Now that the subscription exists, let the compositor flush the calls it
    // held back while the shell was starting.
    unawaited(
      ref
          .read(platformManagerProvider.notifier)
          .request(const NotificationReadyRequest()),
    );
    // A new session only keeps the notification history. Synthesized attention
    // entries cannot survive it, and every restored notification belongs to a
    // previous window instance: it starts read and closed so it never drives a
    // dot, and is shown as history only.
    ref.listen(metaWindowManagerProvider, (previous, next) {
      if (previous == null) {
        return;
      }
      // A synthesized attention request is moot once its window is gone.
      previous
          .where((id) => !next.contains(id))
          .forEach(_pruneAttentionNotification);
    });
    final restored = stateOrNull;
    if (restored == null) {
      return NotificationManagerState(
        notificationMap: <int, Notification>{}.lock,
        lastIndex: 0,
      );
    }
    final history = <int, Notification>{};
    restored.notificationMap.forEach((id, notification) {
      if (notification.isSynthetic) {
        return;
      }
      history[id] = notification.copyWith(isRead: true, isClosed: true);
    });
    return restored.copyWith(notificationMap: history.lock);
  }

  /// Drops the live notice synthesized for [metaWindowId] when its window
  /// closes; the request can no longer be acted on.
  void _pruneAttentionNotification(String metaWindowId) {
    final id = _attentionNotificationByWindow[metaWindowId];
    if (id == null) {
      return;
    }
    unawaited(
      _closeNotification(
        id,
        reason: NotificationCloseReason.dismissed,
        markRead: true,
      ),
    );
  }

  void _onPlatformEvent(PlatformEvent event) {
    switch (event) {
      case NotificationReceivedEvent(:final message):
        _onNewNotification(message.callToken, message.notification);
      case NotificationCloseRequestedEvent(:final message):
        // A client closed a live notification: tear down its popup. The entry
        // stays in the persisted history, and `NotificationClosed(reason 3)`
        // is only emitted if it had not already expired.
        closeNotification(
          message.id,
          reason: NotificationCloseReason.closedByCall,
        );
      case WindowActivationRequestedEvent(:final message):
        // The compositor honored an activation token minted for an invoked
        // action and focused the window; the shell must select the workspace
        // and tile that make it visible.
        bringMetaWindowIntoView(ref, message.metaWindowId);
      case WindowAttentionRequestedEvent(:final message):
        // A window asks for attention: synthesize a notification instead of
        // focusing it. Errors are swallowed because a request that arrives
        // before the window is known can simply be dropped.
        unawaited(_onWindowAttentionRequested(message.metaWindowId));
      case WindowAttentionReleasedEvent(:final message):
        _onWindowAttentionReleased(message.metaWindowId);
      default:
        break;
    }
  }

  void _onNewNotification(int callToken, DbusNotification newNotification) {
    final replacesId = newNotification.replacesId;
    final int id;
    if (replacesId != 0) {
      final existing = state.notificationMap[replacesId];
      // A closed id is no longer known to the sender: treat it as new.
      if (existing != null && !existing.isClosed) {
        id = _replaceNotification(replacesId, newNotification);
      } else {
        id = _addNotification(newNotification);
      }
    } else {
      id = _addNotification(newNotification);
    }
    // The compositor's `Notify` reply waits for this id.
    unawaited(_sendNotifyResult(callToken, id));
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
      targetMetaWindowId: _resolveTargetMetaWindowId(dbusNotification),
    );
  }

  /// The exact MetaWindow instance that sent a D-Bus notification, or `null`
  /// when the sender has no live window (e.g. `notify-send`).
  String? _resolveTargetMetaWindowId(DbusNotification notification) {
    final pid = notification.pid;
    if (pid == null) {
      return null;
    }
    return ref.read(pidToMetaWindowIdProvider(pid));
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

  /// Turns a window attention request into a synthesized notification.
  ///
  /// There is no D-Bus sender here: the notification is created by the shell,
  /// routed to the requesting window and, when activated, brings that window
  /// into view through the ordinary click-to-open path. A window that is
  /// already displayed is skipped, so a freshly launched window that activates
  /// itself does not produce a spurious entry.
  Future<void> _onWindowAttentionRequested(String metaWindowId) async {
    final metaWindow = _readMetaWindow(metaWindowId);
    if (metaWindow == null) {
      return;
    }

    // A request already pending for the same window (its popup may have
    // expired) must not stack another notification: its dot already covers it.
    final existingId = _attentionNotificationByWindow[metaWindowId];
    if (existingId != null && state.notificationMap.containsKey(existingId)) {
      return;
    }
    _attentionNotificationByWindow.remove(metaWindowId);

    final targetWindowId = resolveShellWindowForMetaWindow(ref, metaWindowId);
    final route = routeForWindow(
      targetWindowId,
      windowWorkspaceMap: ref.read(windowWorkspaceMapProvider),
      focusedWorkspaceId: ref.read(focusedWorkspaceIdProvider),
      displayedWindowIds: ref.read(displayedWindowIdsProvider),
      displayedEphemeralWindowIds: ref.read(
        displayedEphemeralWindowIdsProvider,
      ),
    );
    if (route is DisplayedNotificationTarget ||
        route is EphemeralDisplayedNotificationTarget) {
      return;
    }

    final appName = await _attentionAppName(metaWindow);
    // The window may have gone away while the name resolved.
    if (!ref.mounted || _readMetaWindow(metaWindowId) == null) {
      return;
    }

    final id = state.lastIndex + 1;
    final notification = Notification(
      id: id,
      appId: metaWindow.appId,
      dbusNotification: DbusNotification(
        pid: metaWindow.pid,
        appName: appName,
        replacesId: 0,
        appIcon: '',
        summary: ref
            .read(shellLocalizationsProvider)
            .requestsAttention(appName),
        actions: const [],
        hints: const NotificationHints(),
        expireTimeout: -1,
      ),
      createdAt: DateTime.now(),
      targetWindowId: targetWindowId,
      targetMetaWindowId: metaWindowId,
      isSynthetic: true,
    );
    _attentionNotificationByWindow[metaWindowId] = id;
    state = state.copyWith(
      notificationMap: state.notificationMap.add(id, notification),
      lastIndex: id,
    );
    notificationLog.info(
      'Synthesized attention notification $id for window $metaWindowId '
      '("$appName")',
    );
    _showPopup(notification);
  }

  /// Drops the live notification synthesized for [metaWindowId] when the
  /// window no longer asks for attention. Like every synthesized entry it is
  /// transient, so it is forgotten rather than kept in history.
  void _onWindowAttentionReleased(String metaWindowId) {
    final id = _attentionNotificationByWindow[metaWindowId];
    if (id == null) {
      return;
    }
    if (!state.notificationMap.containsKey(id)) {
      _attentionNotificationByWindow.remove(metaWindowId);
      return;
    }
    notificationLog.info('Window attention withdrawn for $metaWindowId');
    closeNotification(
      id,
      reason: NotificationCloseReason.dismissed,
      markRead: true,
    );
  }

  /// The display name shown in the synthesized notification: the localized
  /// desktop-entry name when the app id resolves, otherwise the best window
  /// identity available.
  Future<String> _attentionAppName(MetaWindow metaWindow) async {
    final appId = metaWindow.appId;
    if (appId != null) {
      try {
        final entry = await ref.read(
          localizedDesktopEntryForIdProvider(appId).future,
        );
        final name = entry?.entries[DesktopEntryKey.name.string];
        if (name != null && name.isNotEmpty) {
          return name;
        }
      } on Object catch (_) {
        // Fall through to the window identity.
      }
    }
    return metaWindow.title ??
        metaWindow.windowClass ??
        appId ??
        ref.read(shellLocalizationsProvider).application;
  }

  /// Reads a meta window state, returning `null` while it is not initialized.
  MetaWindow? _readMetaWindow(String metaWindowId) {
    try {
      return ref.read(metaWindowStateProvider(metaWindowId));
    } on Object catch (_) {
      return null;
    }
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

  /// Clears every notification: live popups are torn down and the persisted
  /// history is emptied.
  ///
  /// Already-closed history entries are removed without a second
  /// `NotificationClosed` signal.
  void dismissAllNotifications() {
    unawaited(_dismissAllNotifications());
  }

  Future<void> _dismissAllNotifications() async {
    // Snapshot the ids: each close mutates the map.
    for (final id in state.notificationMap.keys.toList()) {
      await _closeNotification(
        id,
        reason: NotificationCloseReason.dismissed,
        markRead: true,
        removeFromHistory: true,
      );
    }
  }

  Future<void> _openNotification(int id) async {
    final notification = state.notificationMap[id];
    if (notification == null) {
      return;
    }
    // The target is resolved at reception; re-resolve in case it could not be
    // mapped yet when the notification arrived, then fall back to the app id.
    final appId = notification.appId;
    final target =
        notification.targetWindowId ??
        resolveNotificationTargetWindow(ref, notification.dbusNotification) ??
        (appId == null ? null : persistentWindowForAppId(ref, appId));

    // Keep the spec's default action: alongside revealing the window, the
    // sender is told the notification was activated.
    final defaultAction = defaultNotificationAction(
      parseNotificationActions(notification.dbusNotification.actions),
    );
    if (defaultAction != null && !notification.isClosed) {
      // Give the sender a token to activate its own window before telling it
      // the action was invoked (the spec allows ActivationToken first).
      await _emitActivationToken(id, notification.targetMetaWindowId);
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
    await _emitActivationToken(id, notification.targetMetaWindowId);
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

    if (notification.isSynthetic) {
      _clearPopup(id);
      if (reason == NotificationCloseReason.expired) {
        // The popup is gone but the request still stands: keep the entry
        // unread so its workspace dot survives while the window is open. It is
        // forgotten once seen, withdrawn, or when the window closes.
        state = state.copyWith(
          notificationMap: state.notificationMap.add(
            id,
            notification.copyWith(isClosed: true),
          ),
        );
        return;
      }
      // Seen (click, dismiss, window displayed) or withdrawn: synthesized
      // attention entries are transient and never enter the history.
      state = state.copyWith(notificationMap: state.notificationMap.remove(id));
      _attentionNotificationByWindow.removeWhere((_, value) => value == id);
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

  Future<void> _sendNotifyResult(int callToken, int id) async {
    try {
      await ref
          .read(platformManagerProvider.notifier)
          .request(
            NotificationNotifyResultRequest(
              message: NotificationNotifyResultMessage(
                callToken: callToken,
                id: id,
              ),
            ),
          );
    } on Object catch (error) {
      notificationLog.warning(
        'Failed to answer Notify($callToken) with id $id',
        error,
      );
    }
  }

  /// Asks the compositor to mint an activation token for [id]'s window and
  /// emit `ActivationToken` before the `ActionInvoked` that follows.
  ///
  /// A notification with no target MetaWindow (a system sender) has nothing to
  /// activate, so no token is minted.
  Future<void> _emitActivationToken(int id, String? metaWindowId) async {
    if (metaWindowId == null) {
      return;
    }
    try {
      await ref
          .read(platformManagerProvider.notifier)
          .request(
            NotificationActivationTokenRequest(
              message: NotificationActivationTokenMessage(
                id: id,
                metaWindowId: metaWindowId,
              ),
            ),
          );
    } on Object catch (error) {
      notificationLog.warning(
        'Failed to mint an activation token for notification $id',
        error,
      );
    }
  }

  Future<void> _emitActionInvoked(int id, String actionKey) async {
    try {
      await ref
          .read(platformManagerProvider.notifier)
          .request(
            NotificationActionInvokedRequest(
              message: NotificationActionInvokedMessage(
                id: id,
                actionKey: actionKey,
              ),
            ),
          );
    } on Object catch (error) {
      notificationLog.warning(
        'Failed to emit ActionInvoked($id, $actionKey)',
        error,
      );
    }
  }

  Future<void> _emitNotificationClosed(int id, int reason) async {
    try {
      await ref
          .read(platformManagerProvider.notifier)
          .request(
            NotificationClosedRequest(
              message: NotificationClosedMessage(id: id, reason: reason),
            ),
          );
    } on Object catch (error) {
      notificationLog.warning(
        'Failed to emit NotificationClosed($id, $reason)',
        error,
      );
    }
  }
}
