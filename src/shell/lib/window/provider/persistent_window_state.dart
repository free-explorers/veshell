import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/model/launch_config.serializable.dart';
import 'package:shell/application/provider/app_launch.dart';
import 'package:shell/shared/persistence/persistable_provider.mixin.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/window/model/matching_info.serializable.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
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

  late MatchingInfo _matchingInfo;

  StreamSubscription<List<int>>? _stderrStreamSubscription;
  StreamSubscription<List<int>>? _stdoutStreamSubscription;

  @override
  PersistentWindow build(PersistentWindowId windowId) {
    final window = getPersisted(PersistentWindow.fromJson)
        ?.copyWith(isWaitingForSurface: false, surfaceId: null);

    if (window != null) {
      initialize(window);
      return window;
    }
    throw Exception('PersistentWindowState $windowId not yet initialized');
  }

  MatchingInfo getMatchingInfo() => _matchingInfo;

  @override
  void initialize(PersistentWindow window) {
    _matchingInfo = MatchingInfo.fromWindowProperties(
      window.properties,
    );
    super.initialize(window);
    persistChanges();
  }

  @override
  void setSurface(SurfaceId surfaceId) {
    _matchingInfo = _matchingInfo.copyWith(
      matchedAtTime: DateTime.now(),
      matchedWhileWaiting: state.isWaitingForSurface,
    );
    state = state.copyWith(
      surfaceId: surfaceId,
      isWaitingForSurface: false,
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
    _matchingInfo = MatchingInfo.fromWindowProperties(state.properties);
    print('onSurfaceIsDestroyed');
    stopGatheringProcessLogs();
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
      gatherProcessLogs(process);
      state = state.copyWith(isWaitingForSurface: true);
      _matchingInfo = _matchingInfo.copyWith(
        waitingForAppSince: DateTime.now(),
        pid: process.pid,
      );
    }
    return process;
  }

  void gatherProcessLogs(Process process) {
    stopGatheringProcessLogs();

    void onEvent(List<int> event) {
      final string = String.fromCharCodes(event);
      state = state.copyWith(
        executionLogs: [...?state.executionLogs, string],
      );
    }

    _stdoutStreamSubscription = process.stdout.listen(
      onEvent,
    );
    _stderrStreamSubscription = process.stderr.listen(
      onEvent,
    );
  }

  void stopGatheringProcessLogs() {
    _stdoutStreamSubscription?.cancel();
    _stderrStreamSubscription?.cancel();
  }

  void setCustomExec(String? exec) {
    state = state.copyWith(customExec: exec);
  }

  void setDisplayMode(DisplayMode mode) {
    state = state.copyWith(displayMode: mode);
  }
}
