import 'dart:async';
import 'dart:io';

import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/model/launch_config.serializable.dart';
import 'package:shell/application/provider/app_launch.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/window/provider/window_provider.mixin.dart';
import 'package:shell/workspace/provider/window_workspace_map.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'persistent_window_state.g.dart';

/// A tile that survives compositor restarts.
///
/// Identity & persistence rules that make it distinct from native windows:
///
/// - `properties.appId` is the **desktop entry id** recorded at creation and
///   never overwritten by whatever the currently displayed native window
///   reports — helper surfaces ("steamwebhelper", dialogs) would otherwise
///   corrupt the tile's identity and make relaunching impossible.
/// - Display-mode preferences persist like `displayMode` and are re-applied
///   to whatever native window becomes displayed.
/// - `build` restores without a native window: `isWaitingForSurface`,
///   `metaWindowId` and `pid` are runtime-only state cleared on boot.
@riverpod
@JsonPersist()
class PersistentWindowState extends _$PersistentWindowState
    with WindowProviderMixin<PersistentWindow> {
  String get _persistKey => 'persistent_window_${windowId.uuid}';
  @override
  PersistentWindow build(PersistentWindowId windowId) {
    persist(
      key: _persistKey,
      ref.watch(persistentStorageStateProvider).requireValue,
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    );

    if (stateOrNull != null) {
      initialize(
        state.copyWith(
          isWaitingForSurface: false,
          metaWindowId: null,
          pid: null,
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

  /// Launches either the custom command or the tile's desktop entry through
  /// the shared tracked launcher, attributing them to this tile.
  ///
  /// The launch-waiting visual state below covers the window-empty handoff
  /// period: until the application presents its first surface, the tile
  /// displays the execution logs instead of an empty card, and the match
  /// bonus lets this tile adopt the first surface to arrive.
  @override
  Future<Process?> launchSelf() async {
    Process? process;
    if (state.customExec != null) {
      process = await ref
          .read(appLaunchProvider.notifier)
          .launchApplication(
            LaunchConfig(command: state.customExec!),
            trackedWindowId: state.windowId,
          );
    } else {
      process = await super.launchSelf();
    }
    if (process != null) {
      state = state.copyWith(isWaitingForSurface: true, pid: process.pid);
      // The pid is the launcher's (systemd-run); multi-process apps report
      // other pids from their own windows. It is a weak match signal, the
      // waiting bonus is the strong one.
      waitForSurface(process.pid);
      unawaited(
        process.exitCode.then((value) {
          print('process exited with code $value');
          // This failure/success only resets the visual waiting state. The
          // attribution association lives in [AppLaunch] and is cleared
          // there, by the same exit.
          state = state.copyWith(isWaitingForSurface: false);
        }),
      );
    }

    return process;
  }

  void setCustomExec(String? exec) {
    state = state.copyWith(customExec: exec);
  }

  void setDisplayMode(DisplayMode mode) {
    state = state.copyWith(displayMode: mode);
    updateMetaWindowDisplayMode();
  }

  void updateMetaWindowDisplayMode() {
    if (state.metaWindowId == null) return;

    final metaDisplayMode = switch (state.displayMode) {
      DisplayMode.maximized => MetaWindowDisplayMode.maximized,
      DisplayMode.fullscreen => MetaWindowDisplayMode.fullscreen,
      DisplayMode.floating => MetaWindowDisplayMode.floating,
      DisplayMode.game => MetaWindowDisplayMode.fullscreen,
    };

    ref
        .read(metaWindowStateProvider(state.metaWindowId!).notifier)
        .patch(
          MetaWindowPatchMessage.updateDisplayMode(
            id: state.metaWindowId!,
            value: metaDisplayMode,
          ),
        );
  }

  @override
  void onCurrentlyDisplayedMetaWindowChanged(MetaWindowId? metaWindowId) {
    state = state.copyWith(
      metaWindowId: metaWindowId,
      isWaitingForSurface: false,
      pid: metaWindowId != null
          ? ref.read(metaWindowStateProvider(metaWindowId)).pid
          : state.pid,
    );
    updateMetaWindowDisplayMode();
  }

  @override
  void onMetaWindowDisplayedPropertiesChanged(MetaWindow metaWindow) {
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
  }

  @override
  void closeWindow({bool forceRemove = false}) {
    if (state.metaWindowId == null) {
      removeWindow();
      return;
    }
    super.closeWindow();
    for (final dialogWindowId in ref.read(
      dialogSetForWindowProvider(windowId),
    )) {
      ref
          .read(dialogWindowStateProvider(dialogWindowId).notifier)
          .closeWindow();
    }
    if (forceRemove) {
      removeWindow();
    }
  }

  @override
  void removeWindow() {
    ref.read(appLaunchProvider.notifier).forgetWindow(windowId);
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
