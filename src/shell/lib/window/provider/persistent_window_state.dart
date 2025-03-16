import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/model/launch_config.serializable.dart';
import 'package:shell/application/provider/app_launch.dart';
import 'package:shell/shared/persistence/persistable_provider.mixin.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/matching_info_for_window.dart';
import 'package:shell/window/provider/window_properties.dart';
import 'package:shell/window/provider/window_provider.mixin.dart';

part 'persistent_window_state.g.dart';

/// Workspace provider
@riverpod
class PersistentWindowState extends _$PersistentWindowState
    with
        WindowProviderMixin,
        PersistableProvider<PersistentWindow,
            AutoDisposeNotifierProviderRef<PersistentWindow>> {
  @override
  String getPersistentFolder() => 'Window';

  @override
  String getPersistentId() => windowId.toString();

  @override
  PersistentWindow build(PersistentWindowId windowId) {
    final window = getPersisted(PersistentWindow.fromJson)
        ?.copyWith(isWaitingForSurface: false, surfaceId: null, pid: null);

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
  void setSurface(SurfaceId surfaceId) {
    ref
        .read(matchingInfoForWindowProvider(state.windowId).notifier)
        .matched(matchedWhileWaiting: state.isWaitingForSurface);
    state = state.copyWith(
      surfaceId: surfaceId,
      isWaitingForSurface: false,
      pid: ref.read(windowPropertiesStateProvider(surfaceId)).pid,
    );
    super.setSurface(surfaceId);
    persistChanges();
  }

  @override
  void onSurfaceChanged(WindowProperties next) {
    state = state.copyWith(
      properties: next,
    );
    persistChanges();
  }

  @override
  void unsetSurface() {
    super.unsetSurface();
    state = state.copyWith(surfaceId: null);
  }

  @override
  void onSurfaceIsDestroyed() {
    super.onSurfaceIsDestroyed();
    ref.read(matchingInfoForWindowProvider(state.windowId).notifier).reset();
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
      ref
          .read(matchingInfoForWindowProvider(state.windowId).notifier)
          .startMatching(process.pid);
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
  }
}
