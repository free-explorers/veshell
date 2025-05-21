import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/model/launch_config.serializable.dart';
import 'package:shell/application/provider/app_launch.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/shared/persistence/persistable_provider.mixin.dart';
import 'package:shell/wayland/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/window_provider.mixin.dart';

part 'persistent_window_state.g.dart';

/// Workspace provider
@riverpod
class PersistentWindowState extends _$PersistentWindowState
    with
        WindowProviderMixin<PersistentWindow>,
        PersistableProvider<PersistentWindow> {
  @override
  String getPersistentFolder() => 'Window';

  @override
  String getPersistentId() => windowId.toString();

  @override
  PersistentWindow build(PersistentWindowId windowId) {
    final window = getPersisted(PersistentWindow.fromJson)
        ?.copyWith(isWaitingForSurface: false, metaWindowId: null, pid: null);

    if (window != null) {
      initialize(window);
      return window;
    }
    throw Exception('PersistentWindowState $windowId not yet initialized');
  }

  @override
  void initialize(PersistentWindow window) {
    super.initialize(window);
    persistChanges();
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
    persistChanges();
  }

  @override
  void onMetaWindowDisplayedPropertiesChanged(MetaWindow metaWindow) {
    state = state.copyWith(
      properties: WindowProperties.fromMetaWindow(metaWindow),
    );

    persistChanges();
  }
}
