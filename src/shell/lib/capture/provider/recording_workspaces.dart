import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/capture/provider/screen_cast_indicator.dart';
import 'package:shell/meta_window/provider/meta_window_window_map.dart';
import 'package:shell/meta_window/provider/pid_to_meta_window_id.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/screen_manager.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/workspace/provider/window_workspace_map.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'recording_workspaces.g.dart';

/// The workspace focused when each live screen cast first appeared.
///
/// Last-resort attribution for casts that neither the PipeWire consumer nor
/// the portal `app_id` can place: the workspace the user was on when the share
/// started. Captured once per session so navigating away does not move the
/// indicator.
@Riverpod(keepAlive: true)
class ScreenCastOriginWorkspaces extends _$ScreenCastOriginWorkspaces {
  @override
  Map<String, WorkspaceId> build() {
    final origin = <String, WorkspaceId>{};
    _seed(origin, ref.read(screenCastIndicatorProvider).keys);
    ref.listen(screenCastIndicatorProvider, (_, next) {
      final updated = Map<String, WorkspaceId>.from(state)
        ..removeWhere((session, _) => !next.containsKey(session));
      _seed(updated, next.keys);
      state = updated;
    });
    return origin;
  }

  void _seed(Map<String, WorkspaceId> origin, Iterable<String> sessions) {
    final workspaceId = _focusedWorkspace();
    if (workspaceId == null) {
      return;
    }
    for (final session in sessions) {
      origin.putIfAbsent(session, () => workspaceId);
    }
  }

  WorkspaceId? _focusedWorkspace() {
    final screenId = ref.read(focusedScreenProvider);
    if (screenId == null) {
      return null;
    }
    final screen = ref.read(screenStateProvider(screenId));
    if (screen.workspaceList.isEmpty) {
      return null;
    }
    return screen.workspaceList[screen.selectedIndex];
  }
}

/// Workspaces that host an application currently sharing its screen.
///
/// Identity is layered, most trustworthy first:
/// 1. the process consuming the stream, read by the compositor from the
///    PipeWire graph (`ScreenCastConsumerPids`) and mapped pid -> meta window
///    -> workspace;
/// 2. the portal `app_id`, resolved through the same desktop-entry lookup that
///    derived the tiles' `appId`, so binary names and `StartupWMClass` still
///    match;
/// 3. the workspace focused when the cast started.
@riverpod
Future<ISet<WorkspaceId>> recordingWorkspaces(Ref ref) async {
  final streams = ref.watch(screenCastIndicatorProvider);
  if (streams.isEmpty) {
    return <WorkspaceId>{}.lock;
  }
  final origins = ref.watch(screenCastOriginWorkspacesProvider);
  final consumerPids = ref.watch(screenCastConsumerPidsProvider);

  // Workspaces holding each tile app id, for the app-id fallback.
  final tileWorkspaces = <String, Set<WorkspaceId>>{};
  for (final screenId in ref.watch(screenManagerProvider).screenIds) {
    for (final workspaceId
        in ref.watch(screenStateProvider(screenId)).workspaceList) {
      final workspace = ref.watch(workspaceStateProvider(workspaceId));
      for (final windowId in workspace.tileableWindowList) {
        final appId = _persistentAppId(ref, windowId);
        if (appId != null && appId.isNotEmpty) {
          tileWorkspaces
              .putIfAbsent(appId, () => <WorkspaceId>{})
              .add(workspaceId);
        }
      }
    }
  }

  final recording = <WorkspaceId>{};
  final unmatched = <String>[];
  for (final entry in streams.entries) {
    final session = entry.key;

    // 1. The compositor-observed consumer process.
    final pid = consumerPids[session];
    final pidWorkspace = pid == null ? null : _workspaceForPid(ref, pid);
    if (pidWorkspace != null) {
      recording.add(pidWorkspace);
      continue;
    }

    // 2. The client-reported app id, canonicalized to a desktop entry.
    final ids = <String>{};
    final appId = entry.value.appId;
    if (appId.isNotEmpty) {
      ids.add(appId);
      final resolved = await ref.watch(
        localizedDesktopEntryForIdProvider(appId).future,
      );
      final canonical = resolved?.desktopEntry.id;
      if (canonical != null && canonical.isNotEmpty) {
        ids.add(canonical);
      }
    }
    final matched = ids
        .expand((id) => tileWorkspaces[id] ?? const <WorkspaceId>{})
        .toSet();
    if (matched.isNotEmpty) {
      recording.addAll(matched);
      continue;
    }

    // 3. The workspace focused when the cast started.
    final origin = origins[session];
    if (origin != null) {
      recording.add(origin);
    } else {
      unmatched.add(session);
    }
  }

  if (recording.isEmpty) {
    captureLog.info(
      'No workspace matched screen casts (consumer pids: $consumerPids, '
      'tile app ids: ${tileWorkspaces.keys})',
    );
  } else if (unmatched.isNotEmpty) {
    captureLog.info('Screen casts without an app identity: $unmatched');
  } else {
    captureLog.fine('Screen cast workspaces $recording');
  }
  return recording.lock;
}

/// The workspace of the tile displaying [pid], or `null` when the process has
/// no mapped window (yet).
WorkspaceId? _workspaceForPid(Ref ref, int pid) {
  final metaWindowId = ref.watch(pidToMetaWindowIdProvider(pid));
  if (metaWindowId == null) {
    return null;
  }
  final windowId = ref.watch(metaWindowWindowMapProvider)[metaWindowId];
  if (windowId == null) {
    return null;
  }
  return ref.watch(windowWorkspaceMapProvider)[windowId];
}

/// The desktop entry id recorded on a tile, or `null` while its state is not
/// initialized yet.
String? _persistentAppId(Ref ref, PersistentWindowId windowId) {
  try {
    return ref.watch(
      persistentWindowStateProvider(
        windowId,
      ).select((window) => window.properties.appId),
    );
  } on Object catch (_) {
    return null;
  }
}
