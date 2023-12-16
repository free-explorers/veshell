import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/manager/platform_api/platform_api.provider.dart';
import 'package:shell/manager/surface/xdg_surface/xdg_surface.provider.dart';
import 'package:shell/manager/surface/xdg_toplevel/xdg_toplevel.model.dart';
import 'package:shell/manager/surface/xdg_toplevel/xdg_toplevel_surface.dart';
import 'package:shell/manager/wayland/event/commit_surface/commit_surface.model.serializable.dart';
import 'package:shell/manager/wayland/request/maximize_window/maximize_window.model.serializable.dart';
import 'package:shell/manager/wayland/request/resize_window/resize_window.model.serializable.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';

part 'xdg_toplevel.provider.g.dart';

@Riverpod(keepAlive: true)
XdgToplevelSurface xdgToplevelSurfaceWidget(
  XdgToplevelSurfaceWidgetRef ref,
  int surfaceId,
) {
  return XdgToplevelSurface(
    key: ref.watch(
      xdgSurfaceStatesProvider(surfaceId).select((state) => state.widgetKey),
    ),
    surfaceId: surfaceId,
  );
}

@Riverpod(keepAlive: true)
class XdgToplevelStates extends _$XdgToplevelStates {
  @override
  XdgToplevelState build(int surfaceId) {
    return const XdgToplevelState(
      visible: true,
      title: '',
      appId: '',
      tilingRequested: null,
    );
  }

  /// Update state from surface commit
  void onCommit(XdgToplevelCommitSurfaceMessage message) {
    state = state.copyWith(
      title: message.title ?? '',
      appId: message.appId ?? '',
      parentSurfaceId: message.parentSurfaceId,
    );
  }

  set visible(bool value) {
    if (value != state.visible) {
      ref
          .read(platformApiProvider.notifier)
          .changeWindowVisibility(surfaceId, value);
      state = state.copyWith(visible: value);
    }
  }

  void requestMaximize(bool maximize) {
    state = state.copyWith(
      tilingRequested: maximize ? Tiling.maximized : Tiling.none,
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

  void requestInteractiveMove() {
    /* state = state.copyWith(
      interactiveMoveRequested: Object(),
    ); */
  }

  void requestInteractiveResize(ResizeEdge edge) {
    /* state = state.copyWith(
      interactiveResizeRequested: ResizeEdgeObject(edge),
    ); */
  }

  void setDecoration(ToplevelDecoration decoration) {
    /* state = state.copyWith(
      decoration: decoration,
    ); */
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
    ref.invalidate(xdgToplevelSurfaceWidgetProvider(surfaceId));
    ref.invalidate(xdgToplevelStatesProvider(surfaceId));
  }
}
