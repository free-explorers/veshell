import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/model/xdg_surface.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';

part 'xdg_surface_state.g.dart';

@riverpod
class XdgSurfaceState extends _$XdgSurfaceState {
  late final KeepAliveLink _keepAliveLink;

  @override
  XdgSurface build(SurfaceId surfaceId) {
    _keepAliveLink = ref.keepAlive();
    ref.onDispose(() {
      print('disposing XdgSurfaceStateProvider $surfaceId');
    });

    // 1. Is a texture attached?
    // 2. Does it have a role?
    ref.listen(
      wlSurfaceStateProvider(surfaceId)
          .select((value) => (value.texture, value.role)),
      (_, __) => _checkIfMapped(),
    );

    return XdgSurface(
      mapped: false,
      geometry: Rect.zero,
      popups: IList(),
    );
  }

  void commit({
    required Rect? geometry,
  }) {
    state = state.copyWith(
      geometry: geometry,
    );
  }

  void addPopup(SurfaceId surfaceId) {
    state = state.copyWith(
      popups: state.popups.add(surfaceId),
    );
  }

  void removePopup(SurfaceId surfaceId) {
    state = state.copyWith(
      popups: state.popups.remove(surfaceId),
    );
  }

  void _checkIfMapped() {
    final hasTexture =
        ref.read(wlSurfaceStateProvider(surfaceId)).texture != null;

    final hasRole = ref.read(wlSurfaceStateProvider(surfaceId)).role != null;

    state = state.copyWith(
      mapped: hasTexture && hasRole,
    );
  }

  void dispose() {
    _keepAliveLink.close();
  }
}
