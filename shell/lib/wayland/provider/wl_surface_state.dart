import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/subsurface_state.dart';
import 'package:shell/wayland/provider/xdg_surface_state.dart';

part 'wl_surface_state.g.dart';

@riverpod
class WlSurfaceState extends _$WlSurfaceState {
  late final KeepAliveLink _keepAliveLink;

  @override
  WlSurface build(SurfaceId surfaceId) {
    throw Exception('WlSurface $surfaceId not yet initialized');
  }

  void initialize() {
    print('initialize $surfaceId');
    _keepAliveLink = ref.keepAlive();
    ref.onDispose(() {
      print('disposing WlSurfaceStateProvider $surfaceId');
    });

    state = WlSurface(
      surfaceId: surfaceId,
      role: null,
      texture: null,
      scale: 1,
      subsurfacesBelow: IList(),
      subsurfacesAbove: IList(),
      inputRegion: Rect.zero,
    );
  }

  void commit({
    required SurfaceRole? role,
    required TextureId textureId,
    required Size surfaceSize,
    required int scale,
    required IList<int> subsurfacesBelow,
    required IList<int> subsurfacesAbove,
    required Rect inputRegion,
  }) {
    state = state.copyWith(
      role: role ?? state.role,
      texture: SurfaceTexture(
        id: textureId,
        size: surfaceSize,
      ),
      scale: scale,
      subsurfacesBelow: subsurfacesBelow,
      subsurfacesAbove: subsurfacesAbove,
      inputRegion: inputRegion,
    );
  }

  void removeSubsurface(SurfaceId subsurface) {
    state = state.copyWith(
      subsurfacesBelow: state.subsurfacesBelow.remove(subsurface),
      subsurfacesAbove: state.subsurfacesAbove.remove(subsurface),
    );
  }

  bool mapped() {
    switch (state.role) {
      case SurfaceRole.xdgToplevel || SurfaceRole.xdgPopup:
        return ref.read(xdgSurfaceStateProvider(surfaceId)).mapped;
      case SurfaceRole.subsurface:
        return ref.read(subsurfaceStateProvider(surfaceId)).mapped;
      case SurfaceRole.x11Surface || null:
        return false;
    }
  }

  void dispose() {
    _keepAliveLink.close();
  }
}
