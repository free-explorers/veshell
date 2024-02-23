import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'wl_surface_state.g.dart';

@riverpod
class WlSurfaceState extends _$WlSurfaceState {
  late final KeepAliveLink _keepAliveLink;

  @override
  WlSurface build(SurfaceId surfaceId) {
    throw Exception('WlSurface $surfaceId not yet initialized');
  }

  void initialize() {
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
      role: role,
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

  void dispose() {
    _keepAliveLink.close();
  }
}
