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
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/window/provider/window_provider.mixin.dart';
import 'package:shell/workspace/provider/window_workspace_map.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'persistent_window_state.g.dart';

/// Workspace provider
@riverpod
@JsonPersist()
class PersistentWindowState extends _$PersistentWindowState
    with WindowProviderMixin<PersistentWindow> {
  String get _persistKey => 'persistent_window_${windowId.uuid}';
  @override
  PersistentWindow build(PersistentWindowId windowId) {
    persist(
      key: _persistKey,
      storage: ref.watch(persistentStorageStateProvider).requireValue,
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

  @override
  Future<Process?> launchSelf() async {
    Process? process;
    if (state.customExec != null) {
      process = await ref.read(appLaunchProvider.notifier).launchApplication(
            LaunchConfig(command: state.customExec!),
          );
    } else {
      process = await super.launchSelf();
    }
    if (process != null) {
      state = state.copyWith(isWaitingForSurface: true, pid: process.pid);
      waitForSurface(process.pid);
      unawaited(
        process.exitCode.then((value) {
          print('process exited with code $value');
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

    ref.read(metaWindowStateProvider(state.metaWindowId!).notifier).patch(
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
    state = state.copyWith(
      properties: WindowProperties.fromMetaWindow(metaWindow),
    );
  }

  @override
  void closeWindow({bool forceRemove = false}) {
    if (state.metaWindowId == null) {
      removeWindow();
      return;
    }
    super.closeWindow();
    for (final dialogWindowId
        in ref.read(dialogSetForWindowProvider(windowId))) {
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
