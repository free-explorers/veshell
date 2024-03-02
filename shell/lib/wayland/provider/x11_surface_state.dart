import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/model/x11_surface.dart';

part 'x11_surface_state.g.dart';

@riverpod
class X11SurfaceState extends _$X11SurfaceState {
  late final KeepAliveLink _keepAliveLink;

  @override
  X11Surface build(X11SurfaceId x11SurfaceId) {
    throw Exception('X11Surface $x11SurfaceId not yet initialized');
  }

  void initialize() {
    _keepAliveLink = ref.keepAlive();
    ref.onDispose(() {
      print('disposing X11SurfaceStateProvider $x11SurfaceId');
    });

    state = X11Surface(
      x11SurfaceId: x11SurfaceId,
      surfaceId: null,
    );
  }

  void map({
    required SurfaceId surfaceId,
  }) {
    state = state.copyWith(
      surfaceId: surfaceId,
    );
  }

  void unmap() {
    state = state.copyWith(
      surfaceId: null,
    );
  }

  void dispose() {
    _keepAliveLink.close();
  }
}
