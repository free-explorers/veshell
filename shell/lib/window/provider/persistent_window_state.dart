import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
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
    state = state.copyWith(surfaceId: null);
    _matchingInfo = MatchingInfo.fromWindowProperties(state.properties);
  }

  @override
  Future<Process?> launchSelf() async {
    final process = await super.launchSelf();
    if (process != null) {
      state = state.copyWith(isWaitingForSurface: true);
      _matchingInfo = _matchingInfo.copyWith(
        waitingForAppSince: DateTime.now(),
        pid: process.pid,
      );
    }
    return process;
  }
}
