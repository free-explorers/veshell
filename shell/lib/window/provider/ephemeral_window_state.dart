import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/window/model/ephemeral_window.dart';
import 'package:shell/window/model/matching_info.serializable.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/window_provider.mixin.dart';

part 'ephemeral_window_state.g.dart';

/// Workspace provider
@riverpod
class EphemeralWindowState extends _$EphemeralWindowState
    with WindowProviderMixin {
  late MatchingInfo _matchingInfo;

  @override
  EphemeralWindow build(EphemeralWindowId windowId) {
    throw Exception('EphemeralWindowState $windowId not yet initialized');
  }

  MatchingInfo getMatchingInfo() => _matchingInfo;

  @override
  void initialize(EphemeralWindow window) {
    _matchingInfo = MatchingInfo.fromWindowProperties(
      window.properties,
    );
    super.initialize(window);
  }

  @override
  void setSurface(SurfaceId surfaceId) {
    _matchingInfo = _matchingInfo.copyWith(
      matchedAtTime: DateTime.now(),
      matchedWhileWaiting: true,
    );
    state = state.copyWith(
      surfaceId: surfaceId,
    );
    super.setSurface(surfaceId);
  }

  @override
  void onSurfaceChanged(WindowProperties next) {
    state = state.copyWith(
      properties: next,
    );
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
      _matchingInfo = _matchingInfo.copyWith(
        waitingForAppSince: DateTime.now(),
        pid: process.pid,
      );
    }
    return process;
  }
}
