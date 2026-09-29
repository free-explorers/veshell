import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/provider/meta_window_window_map.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/platform/model/request/activate_window/activate_window.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/screen_manager.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/ephemeral_window.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/workspace/provider/window_workspace_map.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

/// Brings the shell window [windowId] into view.
///
/// A persistent tile is revealed by selecting its workspace and tile on the
/// screen that owns it (hiding the overview, which would otherwise cover the
/// workspace). An ephemeral window is revealed by opening the overview on its
/// screen to that window. The owning meta window is activated on the
/// compositor so it also receives keyboard focus.
void bringWindowIntoView(Ref ref, WindowId windowId) {
  switch (windowId) {
    case PersistentWindowId():
      _revealPersistent(ref, windowId);
    case EphemeralWindowId():
      _revealEphemeral(ref, windowId);
    case DialogWindowId():
      _revealDialog(ref, windowId);
  }
}

/// Brings the shell window owning [metaWindowId] into view.
void bringMetaWindowIntoView(Ref ref, MetaWindowId metaWindowId) {
  final windowId = ref.read(metaWindowWindowMapProvider)[metaWindowId];
  if (windowId != null) {
    bringWindowIntoView(ref, windowId);
  }
}

/// A dialog is shown above its parent, so reveal the parent tile instead.
void _revealDialog(Ref ref, DialogWindowId windowId) {
  final dialog = _readOrNull<DialogWindow>(
    () => ref.read(dialogWindowStateProvider(windowId)),
  );
  if (dialog != null) {
    bringWindowIntoView(ref, dialog.parentWindowId);
  }
}

void _revealPersistent(Ref ref, PersistentWindowId windowId) {
  final workspaceId = _workspaceForWindow(ref, windowId);
  final screenId =
      workspaceId == null ? null : _screenForWorkspace(ref, workspaceId);
  if (workspaceId == null || screenId == null) {
    // The tile is not placed on any screen: nothing to navigate, but a live
    // meta window can still be activated.
    navigationLog.warning(
      'No screen/workspace found for persistent window $windowId '
      '(workspace=$workspaceId); activating only',
    );
    _activate(ref, windowId);
    return;
  }

  navigationLog.info(
    'Revealing persistent window $windowId: screen $screenId, '
    'workspace $workspaceId',
  );
  ref.read(focusedScreenProvider.notifier).setFocusedScreen(screenId);
  // The overview would keep covering the workspace we are navigating to.
  ref.read(overviewStateProvider(screenId).notifier).hide();

  final screen = ref.read(screenStateProvider(screenId));
  final workspaceIndex = screen.workspaceList.indexOf(workspaceId);
  if (workspaceIndex != -1) {
    ref
        .read(screenStateProvider(screenId).notifier)
        .selectWorkspace(workspaceIndex);
  }

  final workspace = ref.read(workspaceStateProvider(workspaceId));
  if (workspace.tileableWindowList.contains(windowId)) {
    ref
        .read(workspaceStateProvider(workspaceId).notifier)
        .selectWindow(windowId);
  } else {
    navigationLog.warning(
      'Window $windowId is not in workspace $workspaceId tile list',
    );
  }

  _activate(ref, windowId);
}

/// The workspace holding [windowId]: from the map when present, otherwise by
/// scanning the layout (the map can lag behind a restored or just-placed tile).
WorkspaceId? _workspaceForWindow(Ref ref, PersistentWindowId windowId) {
  final mapped = ref.read(windowWorkspaceMapProvider)[windowId];
  if (mapped != null) {
    return mapped;
  }
  for (final screenId in ref.read(screenManagerProvider).screenIds) {
    final screen = ref.read(screenStateProvider(screenId));
    for (final workspaceId in screen.workspaceList) {
      final workspace = ref.read(workspaceStateProvider(workspaceId));
      if (workspace.tileableWindowList.contains(windowId)) {
        return workspaceId;
      }
    }
  }
  return null;
}

void _revealEphemeral(Ref ref, EphemeralWindowId windowId) {
  final window = _readOrNull<EphemeralWindow>(
    () => ref.read(ephemeralWindowStateProvider(windowId)),
  );
  if (window == null) {
    navigationLog.warning('No state for ephemeral window $windowId');
    return;
  }
  navigationLog.info(
    'Revealing ephemeral window $windowId on screen ${window.screenId}',
  );
  ref.read(focusedScreenProvider.notifier).setFocusedScreen(window.screenId);
  ref.read(overviewStateProvider(window.screenId).notifier).show(windowId);
  _activate(ref, windowId);
}

/// The screen whose workspace list contains [workspaceId], or `null`.
ScreenId? _screenForWorkspace(Ref ref, WorkspaceId workspaceId) {
  for (final screenId in ref.read(screenManagerProvider).screenIds) {
    if (ref
        .read(screenStateProvider(screenId))
        .workspaceList
        .contains(workspaceId)) {
      return screenId;
    }
  }
  return null;
}

/// Asks the compositor to activate (focus, and raise for X11) the meta window
/// displayed by [windowId], when the window is still alive.
void _activate(Ref ref, WindowId windowId) {
  final metaWindowId = switch (windowId) {
    PersistentWindowId() =>
      _readOrNull<PersistentWindow>(
        () => ref.read(persistentWindowStateProvider(windowId)),
      )?.metaWindowId,
    EphemeralWindowId() =>
      _readOrNull<EphemeralWindow>(
        () => ref.read(ephemeralWindowStateProvider(windowId)),
      )?.metaWindowId,
    DialogWindowId() =>
      _readOrNull<DialogWindow>(
        () => ref.read(dialogWindowStateProvider(windowId)),
      )?.metaWindowId,
  };
  if (metaWindowId == null) {
    navigationLog.info('No live meta window for $windowId; not activating');
    return;
  }
  final metaWindow = _readOrNull<MetaWindow>(
    () => ref.read(metaWindowStateProvider(metaWindowId)),
  );
  if (metaWindow == null) {
    return;
  }
  navigationLog.info(
    'Activating meta window $metaWindowId (surface ${metaWindow.surfaceId})',
  );
  unawaited(
    ref.read(platformManagerProvider.notifier).request(
          ActivateWindowRequest(
            message: ActivateWindowMessage(
              surfaceId: metaWindow.surfaceId,
              activate: true,
            ),
          ),
        ),
  );
}

/// Reads a provider whose notifier may not be initialized yet, returning
/// `null` instead of throwing.
T? _readOrNull<T>(T Function() read) {
  try {
    return read();
  } on Object catch (_) {
    return null;
  }
}
