import 'package:flutter/foundation.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

/// Where the application that triggered a notification currently lives.
///
/// The notification is always registered in the persisted list; the target
/// only decides which contextual surface (if any) shows a transient popup and
/// which workspace button gets an unread dot.
@immutable
sealed class NotificationTarget {
  /// Const constructor.
  const NotificationTarget();
}

/// The originating window is currently displayed on the focused screen, so the
/// notification only needs to live in the persisted list.
class DisplayedNotificationTarget extends NotificationTarget {
  /// Const constructor.
  const DisplayedNotificationTarget({
    required this.workspaceId,
    required this.windowId,
  });

  /// The workspace the originating window belongs to.
  final WorkspaceId workspaceId;

  /// The originating window.
  final PersistentWindowId windowId;

  @override
  bool operator ==(Object other) =>
      other is DisplayedNotificationTarget &&
      other.workspaceId == workspaceId &&
      other.windowId == windowId;

  @override
  int get hashCode => Object.hash(workspaceId, windowId);
}

/// The originating app lives in a workspace that is not currently displayed.
class WorkspaceNotificationTarget extends NotificationTarget {
  /// Const constructor.
  const WorkspaceNotificationTarget(this.workspaceId);

  /// The workspace that should get the dot and the popup.
  final WorkspaceId workspaceId;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceNotificationTarget && other.workspaceId == workspaceId;

  @override
  int get hashCode => workspaceId.hashCode;
}

/// The originating app lives in the displayed workspace but its tile is not
/// currently visible.
class TileNotificationTarget extends NotificationTarget {
  /// Const constructor.
  const TileNotificationTarget({
    required this.workspaceId,
    required this.windowId,
  });

  /// The workspace the originating window belongs to.
  final WorkspaceId workspaceId;

  /// The window whose panel button should show the popup.
  final PersistentWindowId windowId;

  @override
  bool operator ==(Object other) =>
      other is TileNotificationTarget &&
      other.workspaceId == workspaceId &&
      other.windowId == windowId;

  @override
  int get hashCode => Object.hash(workspaceId, windowId);
}

/// The notification comes from an ephemeral window that is currently displayed
/// in the open overview, so it must stay hidden.
class EphemeralDisplayedNotificationTarget extends NotificationTarget {
  /// Const constructor.
  const EphemeralDisplayedNotificationTarget({
    required this.ephemeralWindowId,
  });

  /// The ephemeral window shown in the overview.
  final EphemeralWindowId ephemeralWindowId;

  @override
  bool operator ==(Object other) =>
      other is EphemeralDisplayedNotificationTarget &&
      other.ephemeralWindowId == ephemeralWindowId;

  @override
  int get hashCode => ephemeralWindowId.hashCode;
}

/// The notification could not be matched to an open tile.
class UnresolvedNotificationTarget extends NotificationTarget {
  /// Const constructor.
  const UnresolvedNotificationTarget();

  @override
  bool operator ==(Object other) => other is UnresolvedNotificationTarget;

  @override
  int get hashCode => runtimeType.hashCode;
}
