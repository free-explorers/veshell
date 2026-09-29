import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_manager.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/provider/meta_window_window_map.dart';
import 'package:shell/meta_window/provider/pid_to_meta_window_id.dart';
import 'package:shell/notification/model/dbus_notification.serializable.dart';
import 'package:shell/notification/model/notification.serializable.dart';
import 'package:shell/notification/model/notification_target.dart';
import 'package:shell/notification/provider/notification_manager.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/screen_manager.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/workspace/provider/window_workspace_map.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'notification_routing.g.dart';

/// The workspace currently displayed on the focused screen, or `null` when no
/// screen exists.
@riverpod
WorkspaceId? focusedWorkspaceId(Ref ref) {
  final screenId = ref.watch(focusedScreenProvider);
  if (screenId == null) {
    return null;
  }
  final screen = ref.watch(screenStateProvider(screenId));
  if (screen.workspaceList.isEmpty) {
    return null;
  }
  return screen.workspaceList[screen.selectedIndex];
}

/// The persistent window tiles currently displayed on the focused screen.
///
/// A tile is displayed when it belongs to the focused workspace and its index
/// falls in the visible range of the workspace's sliding container.
@riverpod
ISet<PersistentWindowId> displayedWindowIds(Ref ref) {
  final workspaceId = ref.watch(focusedWorkspaceIdProvider);
  if (workspaceId == null) {
    return <PersistentWindowId>{}.lock;
  }
  final workspace = ref.watch(workspaceStateProvider(workspaceId));
  final windows = workspace.tileableWindowList;
  if (windows.isEmpty) {
    return <PersistentWindowId>{}.lock;
  }
  final visibleLength =
      workspace.visibleLength < 1 ? 1 : workspace.visibleLength;
  final maxStart =
      (windows.length - visibleLength).clamp(0, windows.length - 1);
  final start = workspace.selectedIndex.clamp(0, maxStart);
  final end = (start + visibleLength).clamp(start + 1, windows.length);
  return windows.sublist(start, end).toISet();
}

/// Ephemeral windows currently displayed in an open overview.
///
/// An ephemeral window only exists on screen while its screen's overview is
/// open, so notifications targeting one must be hidden (not popped) then.
@riverpod
ISet<EphemeralWindowId> displayedEphemeralWindowIds(Ref ref) {
  final displayed = <EphemeralWindowId>{};
  for (final screenId in ref.watch(screenManagerProvider).screenIds) {
    final overview = ref.watch(overviewStateProvider(screenId));
    if (overview.isDisplayed) {
      displayed.addAll(overview.windowList);
    }
  }
  return displayed.lock;
}

/// Routes every known notification to the workspace/window it belongs to.
@riverpod
IMap<int, NotificationTarget> notificationRoutes(Ref ref) {
  final notifications = ref.watch(notificationManagerProvider).notificationMap;
  final windowWorkspaceMap = ref.watch(windowWorkspaceMapProvider);
  final focusedWorkspace = ref.watch(focusedWorkspaceIdProvider);
  final displayedWindows = ref.watch(displayedWindowIdsProvider);
  final displayedEphemeralWindows = ref.watch(
    displayedEphemeralWindowIdsProvider,
  );

  final routes = <int, NotificationTarget>{};
  for (final notification in notifications.values) {
    routes[notification.id] = routeForWindow(
      notification.targetWindowId,
      windowWorkspaceMap: windowWorkspaceMap,
      focusedWorkspaceId: focusedWorkspace,
      displayedWindowIds: displayedWindows,
      displayedEphemeralWindowIds: displayedEphemeralWindows,
    );
  }
  return routes.lock;
}

/// Unread notifications whose originating app lives in a workspace that is not
/// currently displayed. Drives the workspace button dot indicator.
///
/// A notification only counts while the exact MetaWindow it came from is still
/// open: a closed window (or a previous session's instance) leaves only
/// history, so its dot is cleared even if the notification was never seen.
@riverpod
IList<Notification> unreadNotificationsForWorkspace(
  Ref ref,
  WorkspaceId workspaceId,
) {
  final notifications = ref.watch(notificationManagerProvider).notificationMap;
  final routes = ref.watch(notificationRoutesProvider);
  final openMetaWindows = ref.watch(metaWindowManagerProvider);
  final unread = notifications.values
      .where((notification) => !notification.isRead)
      .where(
        (notification) => isNotificationLive(notification, openMetaWindows),
      )
      .where((notification) {
        final route = routes[notification.id];
        return route is WorkspaceNotificationTarget &&
            route.workspaceId == workspaceId;
      })
      .toList()
    ..sort((a, b) => b.id.compareTo(a.id));
  return unread.lock;
}

/// Whether [notification] is still tied to an open MetaWindow.
///
/// `targetMetaWindowId` identifies the exact instance the notification came
/// from, so a relaunched app (new instance) leaves the old notification
/// historical. A notification with no MetaWindow at all (a system sender) is
/// not tied to a closed window and stays live.
bool isNotificationLive(
  Notification notification,
  ISet<MetaWindowId> openMetaWindows,
) {
  final metaWindowId = notification.targetMetaWindowId;
  return metaWindowId == null || openMetaWindows.contains(metaWindowId);
}

/// Pure routing decision, shared by the reactive provider above and the
/// notification manager at reception time.
NotificationTarget routeForWindow(
  WindowId? windowId, {
  required IMap<WindowId, WorkspaceId> windowWorkspaceMap,
  required WorkspaceId? focusedWorkspaceId,
  required ISet<PersistentWindowId> displayedWindowIds,
  required ISet<EphemeralWindowId> displayedEphemeralWindowIds,
}) {
  if (windowId is EphemeralWindowId) {
    // Ephemeral windows are only on screen while their overview is open.
    return displayedEphemeralWindowIds.contains(windowId)
        ? EphemeralDisplayedNotificationTarget(ephemeralWindowId: windowId)
        : const UnresolvedNotificationTarget();
  }
  if (windowId is! PersistentWindowId) {
    return const UnresolvedNotificationTarget();
  }
  final workspaceId = windowWorkspaceMap[windowId];
  if (workspaceId == null) {
    return const UnresolvedNotificationTarget();
  }
  if (workspaceId != focusedWorkspaceId) {
    return WorkspaceNotificationTarget(workspaceId);
  }
  if (displayedWindowIds.contains(windowId)) {
    return DisplayedNotificationTarget(
      workspaceId: workspaceId,
      windowId: windowId,
    );
  }
  return TileNotificationTarget(workspaceId: workspaceId, windowId: windowId);
}

/// Resolves the window that sent a notification, or `null` when the
/// notification should use the default popup.
///
/// The generated D-Bus server already replaces the untrusted `pid` argument
/// with the real session-bus sender pid, which maps to a meta window and then
/// to a shell window. A dialog resolves to its parent persistent tile. An
/// ephemeral window is returned as-is. Only when the pid cannot be mapped at
/// all does the desktop-entry hint provide candidate tiles.
WindowId? resolveNotificationTargetWindow(
  Ref ref,
  DbusNotification notification,
) {
  final pid = notification.pid;
  if (pid != null) {
    final metaWindowId = ref.read(pidToMetaWindowIdProvider(pid));
    if (metaWindowId != null) {
      final resolved = _resolveFromMetaWindow(ref, metaWindowId);
      if (resolved != null) {
        return resolved;
      }
    }
  }
  final appId = notification.hints.desktopEntry;
  if (appId == null) {
    return null;
  }
  return _bestPersistentWindowForAppId(ref, appId);
}

/// The best persistent tile for [appId], or `null`.
///
/// Exposed as a click-time fallback: a notification whose target could not be
/// resolved at reception (for example, its window map was not ready yet) can
/// still be matched by the app id stored on the notification.
PersistentWindowId? persistentWindowForAppId(Ref ref, String appId) =>
    _bestPersistentWindowForAppId(ref, appId);

/// The shell window owning [metaWindowId], or `null` when it is not matched
/// (yet).
///
/// Used to route a synthesized attention notification to the exact window that
/// requested it, rather than the app's best tile.
WindowId? resolveShellWindowForMetaWindow(Ref ref, MetaWindowId metaWindowId) =>
    _resolveFromMetaWindow(ref, metaWindowId);

/// Walks up the meta-window parent chain until it reaches a persistent tile or
/// an ephemeral window. Returns `null` when the chain has no shell window.
WindowId? _resolveFromMetaWindow(Ref ref, MetaWindowId metaWindowId) {
  var current = metaWindowId;
  final visited = <MetaWindowId>{};
  while (visited.add(current)) {
    final windowId = ref.read(metaWindowWindowMapProvider)[current];
    if (windowId is PersistentWindowId || windowId is EphemeralWindowId) {
      return windowId;
    }
    // A dialog (or a meta window not mapped yet): try its parent.
    final parent = _metaWindowParent(ref, current);
    if (parent == null) {
      return null;
    }
    current = parent;
  }
  return null;
}

MetaWindowId? _metaWindowParent(Ref ref, MetaWindowId metaWindowId) {
  try {
    return ref.read(metaWindowStateProvider(metaWindowId)).parent;
  } on Object catch (_) {
    return null;
  }
}

/// Picks the tile that best represents an app when the pid is unknown.
///
/// A displayed tile wins: the app is on screen, so the notification is
/// considered displayed and does not pop. Otherwise a tile in the focused
/// workspace (below its panel button) is preferred over one in another
/// workspace (next to its workspace button).
PersistentWindowId? _bestPersistentWindowForAppId(Ref ref, String appId) {
  final candidates = <PersistentWindowId>[];
  for (final screenId in ref.read(screenManagerProvider).screenIds) {
    final screen = ref.read(screenStateProvider(screenId));
    for (final workspaceId in screen.workspaceList) {
      final workspace = ref.read(workspaceStateProvider(workspaceId));
      for (final windowId in workspace.tileableWindowList) {
        try {
          final window = ref.read(persistentWindowStateProvider(windowId));
          if (window.properties.appId == appId) {
            candidates.add(windowId);
          }
        } on Object catch (_) {
          // The tile state is not initialized yet; skip it.
        }
      }
    }
  }
  if (candidates.isEmpty) {
    return null;
  }
  final displayed = ref.read(displayedWindowIdsProvider);
  for (final candidate in candidates) {
    if (displayed.contains(candidate)) {
      return candidate;
    }
  }
  final focusedWorkspaceId = ref.read(focusedWorkspaceIdProvider);
  final windowWorkspaceMap = ref.read(windowWorkspaceMapProvider);
  for (final candidate in candidates) {
    if (windowWorkspaceMap[candidate] == focusedWorkspaceId) {
      return candidate;
    }
  }
  return candidates.first;
}
