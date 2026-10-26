import 'dart:async';
import 'dart:io';

import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/model/resume_launch_plan.dart';
import 'package:shell/application/provider/app_launch.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/provider/process_info_state.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/platform/model/event/process_info/process_info.serializable.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/systemd/provider/session_guard.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/resume_context_capture.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/window/provider/window_provider.mixin.dart';
import 'package:shell/workspace/provider/window_workspace_map.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'persistent_window_state.g.dart';

/// Storage key under which a persistent tile's state is persisted.
String persistentWindowStorageKey(PersistentWindowId windowId) =>
    'persistent_window_${windowId.uuid}';

/// A tile that survives compositor restarts.
///
/// Identity & persistence rules that make it distinct from native windows:
///
/// - `properties.appId` is the **desktop entry id** recorded at creation and
///   never overwritten by whatever the currently displayed native window
///   reports — helper surfaces ("steamwebhelper", dialogs) would otherwise
///   corrupt the tile's identity and make relaunching impossible. The other
///   identity fields (title, class, startup id, pid) follow the displayed
///   window, so a tile remembers the tab it last showed and a relaunch matches
///   it again even after the window closed.
/// - Display-mode preferences persist like `displayMode` and are re-applied
///   to whatever native window becomes displayed.
/// - `build` restores without a native window: `isWaitingForSurface`,
///   `metaWindowId` and `pid` are runtime-only state cleared on boot.
@riverpod
@JsonPersist()
class PersistentWindowState extends _$PersistentWindowState
    with WindowProviderMixin<PersistentWindow> {
  String get _persistKey => persistentWindowStorageKey(windowId);

  /// Whether the session is being torn down (logout/reboot/shutdown).
  ///
  /// Window-loss and title-change events during teardown are transient: the
  /// last complete resume context must survive into the next session.
  bool get _isSessionLeaving =>
      ref.read(sessionGuardProvider.notifier).isLeaving;

  Timer? _resumeTimeoutTimer;

  /// A resume that has not produced a window by then is shown as retryable.
  static const _resumeTimeout = Duration(seconds: 25);

  @override
  PersistentWindow build(PersistentWindowId windowId) {
    persist(
      key: _persistKey,
      ref.watch(persistentStorageStateProvider).requireValue,
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    );
    ref.onDispose(() {
      _resumeTimeoutTimer?.cancel();
      _resumeTimeoutTimer = null;
    });

    if (stateOrNull != null) {
      initialize(
        state.copyWith(
          isWaitingForSurface: false,
          metaWindowId: null,
          pid: null,
          resumeTimedOut: false,
        ),
      );
      return state;
    }
    throw Exception('PersistentWindowState $windowId not yet initialized');
  }

  Future<void> deletePersistedState() async {
    final storage = ref.read(persistentStorageStateProvider).requireValue;
    ref.onDispose(() {
      storage.delete(_persistKey);
    });
    dispose();
  }

  /// Resumes the tile with its saved working directory, arguments and
  /// documents (or its custom exec).
  ///
  /// The launch-waiting visual state below covers the window-empty handoff
  /// period: until the application presents its first surface, the tile
  /// displays the execution logs instead of an empty card, and the match
  /// bonus lets this tile adopt the first surface to arrive. Sibling tiles of
  /// the same application group are armed as gather candidates too, so a
  /// multi-window application fills them from one launch.
  @override
  Future<Process?> launchSelf() async {
    final home = Platform.environment['HOME'];
    final entry = state.customExec == null
        ? await ref.read(
            localizedDesktopEntryForIdProvider(state.properties.appId).future,
          )
        : null;
    if (!ref.mounted) {
      return null;
    }
    final plan = buildResumeLaunchPlan(
      context: state.resumeContext,
      customExec: state.customExec,
      execTemplate:
          entry?.desktopEntry.entries[DesktopEntryKey.exec.string]?.value,
      entryName: entry?.entries[DesktopEntryKey.name.string],
      entryIcon: entry?.entries[DesktopEntryKey.icon.string],
      homeDirectory: home,
    );
    if (plan == null) {
      matchingLog.info(
        'Cannot launch tile $windowId: no custom exec, no usable desktop '
        'entry and no saved command',
      );
      return null;
    }

    _armSiblingTilesForResume();

    final process = await ref
        .read(appLaunchProvider.notifier)
        .launchApplication(plan.config, trackedWindowId: state.windowId);
    if (!ref.mounted) {
      return process;
    }

    _resumeTimeoutTimer?.cancel();
    state = state.copyWith(
      resumeContext: plan.context.copyWith(
        capturedAt: plan.context.capturedAt ?? DateTime.now(),
      ),
      isWaitingForSurface: true,
      resumeTimedOut: false,
      pid: process.pid,
    );
    // The pid is the launcher's (systemd-run); multi-process apps report
    // other pids from their own windows. It is a weak match signal, the
    // waiting bonus is the strong one.
    waitForSurface(process.pid);
    _resumeTimeoutTimer = Timer(_resumeTimeout, _onResumeTimeout);
    unawaited(
      process.exitCode.then((value) {
        matchingLog.info('Launch of tile $windowId exited with code $value');
        // This failure/success only resets the visual waiting state. The
        // attribution association lives in [AppLaunch] and is cleared
        // there, by the same exit. The tile may have been removed (or its
        // notifier rebuilt) while the process ran, so the notifier state is
        // only touched while it is still mounted.
        if (!ref.mounted) return;
        _resumeTimeoutTimer?.cancel();
        _resumeTimeoutTimer = null;
        state = state.copyWith(isWaitingForSurface: false);
      }),
    );

    return process;
  }

  /// Arms sibling tiles of the same application for the launch burst.
  ///
  /// They receive a small waiting penalty, which keeps the clicked tile first
  /// in line while still letting the matching engine distribute additional
  /// windows from the same launch. Nothing is
  /// persisted: a sibling that receives no window stays a placeholder.
  void _armSiblingTilesForResume() {
    final current = state;
    for (final siblingId
        in ref
            .read(windowManagerProvider)
            .windows
            .whereType<PersistentWindowId>()) {
      if (siblingId == windowId) {
        continue;
      }
      final PersistentWindow sibling;
      try {
        sibling = ref.read(persistentWindowStateProvider(siblingId));
      } on Object {
        continue;
      }
      if (!sameResumeGroup(
        appIdA: current.properties.appId,
        cgroupA: current.resumeContext?.cgroup,
        appIdB: sibling.properties.appId,
        cgroupB: sibling.resumeContext?.cgroup,
      )) {
        continue;
      }
      if (sibling.metaWindowId != null) {
        // A tile already showing a window is not a destination for this burst.
        continue;
      }
      ref
          .read(persistentWindowStateProvider(siblingId).notifier)
          .armForSiblingResume();
    }
  }

  void _onResumeTimeout() {
    _resumeTimeoutTimer = null;
    if (!ref.mounted || !state.isWaitingForSurface) {
      return;
    }
    if (state.metaWindowId != null) {
      return;
    }
    matchingLog.warning(
      'Resume of tile $windowId produced no window within '
      '${_resumeTimeout.inSeconds}s; keeping the saved context',
    );
    state = state.copyWith(isWaitingForSurface: false, resumeTimedOut: true);
  }

  /// Captures process facts into the tile's resume context.
  void captureResumeContext(ProcessInfoMessage? info) {
    if (_isSessionLeaving) {
      return;
    }
    final next = captureResumeContextFromProcessInfo(info);
    if (next == null || sameResumeContext(state.resumeContext, next)) {
      return;
    }
    state = state.copyWith(resumeContext: next);
  }

  void _captureFromPid(int? pid) {
    if (pid == null || pid <= 0) {
      return;
    }
    captureResumeContext(
      ref.read(processInfoStateProvider.notifier).forPid(pid),
    );
  }

  /// Retries a failed or timed-out resume without duplicating a live launch.
  Future<void> retryResume() async {
    ref.read(appLaunchProvider.notifier).cancelPendingLaunch(state.windowId);
    _resumeTimeoutTimer?.cancel();
    _resumeTimeoutTimer = null;
    state = state.copyWith(isWaitingForSurface: false, resumeTimedOut: false);
    await launchSelf();
  }

  /// Clears the saved resume context and title, keeping the tile itself.
  void forgetResumeContext() {
    ref.read(appLaunchProvider.notifier).cancelPendingLaunch(state.windowId);
    _resumeTimeoutTimer?.cancel();
    _resumeTimeoutTimer = null;
    state = state.copyWith(
      resumeContext: null,
      properties: state.properties.copyWith(title: null),
      isWaitingForSurface: false,
      resumeTimedOut: false,
    );
  }

  void setCustomExec(String? exec) {
    state = state.copyWith(customExec: exec);
  }

  void setDisplayMode(DisplayMode mode) {
    state = state.copyWith(displayMode: mode);
    updateMetaWindowDisplayMode();
  }

  void updateMetaWindowDisplayMode() {
    final metaWindowId = state.metaWindowId;
    if (metaWindowId == null) return;

    final metaWindowNotifier = ref.read(
      metaWindowStateProvider(metaWindowId).notifier,
    );

    // Gaming mode owns its own transition: the overlay resizes the window to
    // the monitor's logical size and only then requests fullscreen, so the
    // configure that carries the fullscreen state already has the final size.
    // Requesting fullscreen here, before that resize, latches Chromium to the
    // tile size (the meta window has no `currentOutput` yet at this point).
    if (state.displayMode == DisplayMode.game) {
      syncDialogDisplayModes();
      return;
    }

    final metaDisplayMode = switch (state.displayMode) {
      DisplayMode.maximized => MetaWindowDisplayMode.maximized,
      DisplayMode.fullscreen => MetaWindowDisplayMode.fullscreen,
      DisplayMode.floating => MetaWindowDisplayMode.floating,
      DisplayMode.game => MetaWindowDisplayMode.fullscreen,
    };

    unawaited(
      metaWindowNotifier.patch(
        MetaWindowPatchMessage.updateDisplayMode(
          id: metaWindowId,
          value: metaDisplayMode,
        ),
      ),
    );
    syncDialogDisplayModes();
  }

  /// Mirrors the tile's presentation onto its attached dialogs.
  ///
  /// Tiled dialogs keep `maximized`; only a floating tile puts its dialogs in
  /// floating mode. This is what makes `configure_request` accept their
  /// client-requested positions without changing the dialog area of the other
  /// modes.
  void syncDialogDisplayModes() {
    final dialogIds = ref.read(dialogSetForWindowProvider(windowId));
    for (final dialogId in dialogIds) {
      final MetaWindowId metaWindowId;
      try {
        metaWindowId = ref
            .read(dialogWindowStateProvider(dialogId))
            .metaWindowId;
      } on Object {
        continue;
      }
      try {
        final notifier = ref.read(
          metaWindowStateProvider(metaWindowId).notifier,
        );
        unawaited(
          notifier.patch(
            MetaWindowPatchMessage.updateDisplayMode(
              id: metaWindowId,
              value: dialogMetaWindowDisplayMode(state.displayMode),
            ),
          ),
        );
      } on Object {
        // The dialog's meta window may have been torn down between the two
        // reads; the next routing pass will settle it.
      }
    }
  }

  @override
  void onCurrentlyDisplayedMetaWindowChanged(MetaWindowId? metaWindowId) {
    if (_isSessionLeaving) {
      // The session is ending: applications are being terminated and their
      // windows disappear. Do not adopt a title/pid from that teardown, and do
      // not touch the saved resume context. The runtime window reference is
      // still dropped, so a cancelled shutdown does not leave the tile
      // pointing at a destroyed window.
      if (metaWindowId == null && state.metaWindowId != null) {
        state = state.copyWith(metaWindowId: null, isWaitingForSurface: false);
      }
      return;
    }
    if (metaWindowId == null) {
      // The native window is gone: drop the reference so the tile falls back
      // to its placeholder. Keeping it would make MetaSurfaceWidget read the
      // destroyed MetaWindowState (and updateMetaWindowDisplayMode patch it).
      state = state.copyWith(metaWindowId: null, isWaitingForSurface: false);
      updateMetaWindowDisplayMode();
      return;
    }
    final metaWindow = ref.read(metaWindowStateProvider(metaWindowId));
    _resumeTimeoutTimer?.cancel();
    _resumeTimeoutTimer = null;
    // Keep the appId defined by the desktop entry: the displayed native window
    // may belong to a helper process with a different or unknown app id. The
    // other identity fields follow the displayed window so the stored title
    // tracks what the tile actually shows (used by the next burst and by the
    // relaunch matching).
    state = state.copyWith(
      metaWindowId: metaWindowId,
      isWaitingForSurface: false,
      resumeTimedOut: false,
      pid: metaWindow.pid,
      properties: state.properties.copyWith(
        title: metaWindow.title,
        windowClass: metaWindow.windowClass,
        startupId: metaWindow.startupId,
        pid: metaWindow.pid,
      ),
    );
    updateMetaWindowDisplayMode();
    _captureFromPid(metaWindow.pid);
  }

  @override
  void onMetaWindowDisplayedPropertiesChanged(MetaWindow metaWindow) {
    if (_isSessionLeaving) {
      return;
    }
    // Keep the appId defined by the desktop entry: the displayed native window
    // may belong to a helper process with a different or unknown app id.
    state = state.copyWith(
      properties: state.properties.copyWith(
        title: metaWindow.title,
        windowClass: metaWindow.windowClass,
        startupId: metaWindow.startupId,
        pid: metaWindow.pid,
      ),
    );
    _captureFromPid(metaWindow.pid);
  }

  @override
  void closeWindow({bool forceRemove = false}) {
    // Close the dialogs first: a tile with no displayed window still owns
    // them, and removing the tile below would otherwise leave them dangling.
    for (final dialogWindowId in ref.read(
      dialogSetForWindowProvider(windowId),
    )) {
      ref
          .read(dialogWindowStateProvider(dialogWindowId).notifier)
          .closeWindow();
    }
    if (state.metaWindowId == null) {
      removeWindow();
      return;
    }
    super.closeWindow();
    if (forceRemove) {
      removeWindow();
    }
  }

  @override
  void removeWindow() {
    _resumeTimeoutTimer?.cancel();
    _resumeTimeoutTimer = null;
    // A tile removed while its launch has not produced a window cancels that
    // launch (see [AppLaunch.cancelPendingLaunch]); a tile that showed a window
    // is not "pending" and is left to close through its window.
    ref.read(appLaunchProvider.notifier).cancelPendingLaunch(state.windowId);
    final workspaceId = ref.read(windowWorkspaceMapProvider).get(windowId);
    if (workspaceId != null) {
      ref
          .read(workspaceStateProvider(workspaceId).notifier)
          .removeWindow(windowId);
    }
    ref.read(windowManagerProvider.notifier).removeWindow(state.windowId);
    deletePersistedState();
  }
}
