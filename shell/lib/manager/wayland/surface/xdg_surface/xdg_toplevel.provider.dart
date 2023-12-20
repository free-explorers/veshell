import 'dart:ui';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/manager/wayland/event/commit_surface/commit_surface.model.serializable.dart';
import 'package:shell/manager/wayland/request/maximize_window/maximize_window.model.serializable.dart';
import 'package:shell/manager/wayland/request/resize_window/resize_window.model.serializable.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';
import 'package:shell/manager/wayland/surface/xdg_surface/xdg_surface.model.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';

part 'xdg_toplevel.provider.g.dart';

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
    throw Exception('XdgToplevelSurface state was not initialized');
  }

  void initialize(XdgToplevelCommitSurfaceMessage message) {
    _keepAliveLink = ref.keepAlive();
    ref.onDispose(() {
      print('disposing XdgToplevelStateProvider $surfaceId');
    });

    state = XdgToplevelSurface(
      surfaceId: message.surfaceId,
      appId: message.appId ?? '',
      title: message.title ?? '',
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
