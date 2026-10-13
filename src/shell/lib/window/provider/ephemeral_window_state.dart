import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/app_launch.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/window/model/ephemeral_window.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/window/provider/window_provider.mixin.dart';

part 'ephemeral_window_state.g.dart';

/// Workspace provider
@riverpod
class EphemeralWindowState extends _$EphemeralWindowState
    with WindowProviderMixin<EphemeralWindow> {
  @override
  EphemeralWindow build(EphemeralWindowId windowId) {
    throw Exception('EphemeralWindowState $windowId not yet initialized');
  }

  /// Launches the tile's desktop entry and remembers the process so the tile
  /// can stream its execution logs while it waits for a native window.
  @override
  Future<Process?> launchSelf() async {
    final process = await super.launchSelf();
    if (process == null) {
      matchingLog.info(
        'Launch of ephemeral window $windowId produced no process',
      );
      return null;
    }
    state = state.copyWith(pid: process.pid);
    // The pid is the launcher's (systemd-run); multi-process apps report other
    // pids from their own windows. It is a weak match signal, the waiting bonus
    // is the strong one.
    waitForSurface(process.pid);
    return process;
  }

  @override
  void onCurrentlyDisplayedMetaWindowChanged(MetaWindowId? metaWindowId) {
    if (metaWindowId == null) {
      // The native window is gone: drop the reference so the tile falls back to
      // its launch placeholder. Keeping it would make the widget read the
      // destroyed MetaWindowState.
      state = state.copyWith(metaWindowId: null);
      return;
    }
    final metaWindow = ref.read(metaWindowStateProvider(metaWindowId));
    state = state.copyWith(metaWindowId: metaWindowId, pid: metaWindow.pid);
    ref.read(metaWindowStateProvider(metaWindowId).notifier).patch(
          MetaWindowPatchMessage.updateDisplayMode(
            id: metaWindowId,
            value: MetaWindowDisplayMode.maximized,
          ),
        );
  }

  @override
  void onMetaWindowDisplayedPropertiesChanged(MetaWindow metaWindow) {
    state = state.copyWith(
      properties: WindowProperties.fromMetaWindow(metaWindow),
    );
  }

  @override
  void onMetaWindowRemoved(MetaWindowId metaWindowId) {
    super.onMetaWindowRemoved(metaWindowId);
    removeWindow();
  }

  /// Closes the tile.
  ///
  /// A tile that is still waiting for a surface owns no native window, so
  /// [WindowProviderMixin.closeWindow] would have nothing to close and the tile
  /// would stay stuck on screen. Remove it directly in that case, matching
  /// `PersistentWindowState`.
  @override
  void closeWindow({bool forceRemove = false}) {
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
  void removeWindow({bool forceRemove = false}) {
    // A tile removed while its launch has not produced a window cancels that
    // launch (see [AppLaunch.cancelPendingLaunch]); a tile that showed a window
    // is not "pending" and is left to close through its window.
    ref.read(appLaunchProvider.notifier).cancelPendingLaunch(state.windowId);
    final screenId = state.screenId;
    ref.read(overviewStateProvider(screenId).notifier).removeWindow(windowId);
    ref.read(windowManagerProvider.notifier).removeWindow(state.windowId);
    dispose();
  }
}
