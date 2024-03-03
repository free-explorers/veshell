import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/request/maximize_window/maximize_window.serializable.dart';
import 'package:shell/wayland/model/request/resize_window/resize_window.serializable.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/model/xdg_toplevel.dart';
import 'package:shell/wayland/provider/surface.manager.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';
import 'package:shell/wayland/provider/xdg_surface_state.dart';

part 'xdg_toplevel_state.g.dart';

@riverpod
class XdgToplevelState extends _$XdgToplevelState {
  late final KeepAliveLink _keepAliveLink;

  @override
  XdgToplevel build(SurfaceId surfaceId) {
    throw Exception('XdgToplevel $surfaceId state was not initialized');
  }

  void initialize() {
    _keepAliveLink = ref.keepAlive();
    ref.onDispose(() {
      print('disposing XdgToplevelStateProvider $surfaceId');
    });

    state = const XdgToplevel(
      committed: false,
      appId: null,
      title: null,
      parent: null,
    );
  }

  /// Update state from surface commit
  void onCommit({
    required int? parent,
    required String? appId,
    required String? title,
  }) {
    state = state.copyWith(
      committed: true,
      title: title,
      appId: appId,
      parent: parent,
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
    final mapped = ref.read(xdgSurfaceStateProvider(surfaceId)).mapped;
    if (mapped) {
      ref.read(surfaceMappedProvider.notifier).unmapped(surfaceId);
    }
    _keepAliveLink.close();
  }
}
