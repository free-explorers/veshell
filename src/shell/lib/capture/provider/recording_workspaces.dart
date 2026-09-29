import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/capture/provider/screen_cast_indicator.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_manager.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/provider/meta_window_window_map.dart';
import 'package:shell/workspace/provider/window_workspace_map.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'recording_workspaces.g.dart';

/// The MetaWindows a live screen cast is currently recording.
///
/// The compositor owns the resolution — the consumer process first, then the
/// portal app id resolved to that app's most recently focused window — and
/// patches `isRecording` onto the MetaWindow. The shell only reads the flag, so
/// no workspace- or app-id guessing is involved.
@riverpod
ISet<MetaWindowId> recordingMetaWindows(Ref ref) {
  final metaWindowIds = ref.watch(metaWindowManagerProvider);
  if (metaWindowIds.isEmpty) {
    return <MetaWindowId>{}.lock;
  }
  final recording = <MetaWindowId>{};
  for (final metaWindowId in metaWindowIds) {
    final isRecording = ref.watch(
      metaWindowStateProvider(
        metaWindowId,
      ).select((window) => window.isRecording),
    );
    if (isRecording) {
      recording.add(metaWindowId);
    }
  }
  return recording.lock;
}

/// Workspaces that host a MetaWindow currently being recorded.
///
/// Derived directly from [recordingMetaWindows]: the recording indicator lives
/// on the workspace containing each recording window and on the window's own
/// tile button, which reads `MetaWindow.isRecording` itself.
@riverpod
ISet<WorkspaceId> recordingWorkspaces(Ref ref) {
  final recording = ref.watch(recordingMetaWindowsProvider);
  if (recording.isEmpty) {
    return <WorkspaceId>{}.lock;
  }
  final metaWindowWindowMap = ref.watch(metaWindowWindowMapProvider);
  final windowWorkspaceMap = ref.watch(windowWorkspaceMapProvider);
  final workspaces = <WorkspaceId>{};
  for (final metaWindowId in recording) {
    final windowId = metaWindowWindowMap[metaWindowId];
    if (windowId == null) {
      continue;
    }
    final workspaceId = windowWorkspaceMap[windowId];
    if (workspaceId != null) {
      workspaces.add(workspaceId);
    }
  }
  return workspaces.lock;
}

/// Live screen casts that no workspace or tile indicator can display.
///
/// A cast is orphan when the compositor resolved it to no MetaWindow at all, or
/// to one that is not placed in any workspace (a dialog, an ephemeral window,
/// an unplaced tile). Those are the only casts the persistent bar keeps
/// visible, so it never duplicates a dot that is already shown and never lets a
/// cast go unseen.
@riverpod
ISet<String> orphanScreenCasts(Ref ref) {
  final sessions = ref.watch(screenCastIndicatorProvider);
  if (sessions.isEmpty) {
    return <String>{}.lock;
  }
  final targets = ref.watch(screenCastRecordingTargetsProvider);
  final metaWindowWindowMap = ref.watch(metaWindowWindowMapProvider);
  final windowWorkspaceMap = ref.watch(windowWorkspaceMapProvider);
  final orphans = <String>{};
  for (final session in sessions.keys) {
    final target = targets[session];
    final windowId = target == null ? null : metaWindowWindowMap[target];
    final displayed = windowId != null && windowWorkspaceMap[windowId] != null;
    if (!displayed) {
      orphans.add(session);
    }
  }
  return orphans.lock;
}

/// The live screen cast sessions recording [metaWindowId].
///
/// The tile's stop affordance uses this: stopping every session that resolved
/// to the window (usually one) ends the recording directly from the tile,
/// without waiting for the app or the orphan-only persistent bar.
@riverpod
ISet<String> recordingSessionsForMetaWindow(
  Ref ref,
  MetaWindowId metaWindowId,
) {
  final targets = ref.watch(screenCastRecordingTargetsProvider);
  final sessions = <String>{};
  for (final entry in targets.entries) {
    if (entry.value == metaWindowId) {
      sessions.add(entry.key);
    }
  }
  return sessions.lock;
}
