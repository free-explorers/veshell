import 'dart:ui';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/event/commit_surface/commit_surface.serializable.dart';
import 'package:shell/wayland/model/request/maximize_window/maximize_window.serializable.dart';
import 'package:shell/wayland/model/request/resize_window/resize_window.serializable.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/model/xdg_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'xdg_toplevel_state.g.dart';

/* @Riverpod(keepAlive: true)
XdgToplevelSurfaceWidget xdgToplevelSurfaceWidget(
  XdgToplevelSurfaceWidgetRef ref,
  SurfaceId surfaceId,
) {
  return XdgToplevelSurfaceWidget(
    key: ref.watch(
      xdgSurfaceStatesProvider(surfaceId).select((state) => state.widgetKey),
    ),
    surfaceId: surfaceId,
  );
} */

@riverpod
class XdgToplevelState extends _$XdgToplevelState {
  late final KeepAliveLink _keepAliveLink;

  @override
  XdgToplevelSurface build(SurfaceId surfaceId) {
    throw Exception('XdgToplevelSurface $surfaceId state was not initialized');
  }

  void initialize(XdgToplevelCommitSurfaceMessage message) {
    _keepAliveLink = ref.keepAlive();
    ref.onDispose(() {
      print('disposing XdgToplevelStateProvider $surfaceId');
    });
    print('initializing XdgToplevelStateProvider $surfaceId ${message.appId}');
    state = XdgToplevelSurface(
      surfaceId: message.surfaceId,
      appId: message.appId ?? 'unkown',
      title: message.title ?? 'Unkown',
      parentSurfaceId: message.parentSurfaceId,
      geometry: message.geometry ??
          Rect.fromLTWH(
            message.surface.bufferDelta?.dx ?? 0.0,
            message.surface.bufferDelta?.dy ?? 0.0,
            message.surface.bufferSize?.width ?? 0.0,
            message.surface.bufferSize?.height ?? 0.0,
          ),
    );
  }

  /// Update state from surface commit
  void onCommit(XdgToplevelCommitSurfaceMessage message) {
    state = state.copyWith(
      title: message.title ?? '',
      appId: message.appId ?? '',
      parentSurfaceId: message.parentSurfaceId,
      geometry: message.geometry ??
          Rect.fromLTWH(
            message.surface.bufferDelta?.dx ?? 0.0,
            message.surface.bufferDelta?.dy ?? 0.0,
            message.surface.bufferSize?.width ?? 0.0,
            message.surface.bufferSize?.height ?? 0.0,
          ),
    );
  }

  void maximize(bool value) {
    ref.read(waylandManagerProvider.notifier).request(
          MaximizeWindowRequest(
            message: MaximizeWindowMessage(
              surfaceId: surfaceId,
              isMaximized: value,
            ),
          ),
        );
  }

  void resize(int width, int height) {
    ref.read(waylandManagerProvider.notifier).request(
          ResizeWindowRequest(
            message: ResizeWindowMessage(
              surfaceId: surfaceId,
              width: width,
              height: height,
            ),
          ),
        );
  }

  void setTitle(String title) {
    state = state.copyWith(
      title: title,
    );
  }

  void setAppId(String appId) {
    state = state.copyWith(
      appId: appId,
    );
  }

  void dispose() {
    _keepAliveLink.close();
  }
}
