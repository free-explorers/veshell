import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/event/commit_surface/commit_surface.serializable.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'wl_surface_state.g.dart';

@riverpod
class WlSurfaceState extends _$WlSurfaceState {
  late final KeepAliveLink _keepAliveLink;

  @override
  WlSurface build(SurfaceId surfaceId) {
    throw Exception('WlSurface $surfaceId not yet initialized');
  }

  void initialize({
    required SurfaceId surfaceId,
    required SurfaceRole role,
    required TextureId textureId,
    required int scale,
    required Rect inputRegion,
    required List<int> subsurfacesBelow,
    required List<int> subsurfacesAbove,
    required Offset? bufferDelta,
    required Size? bufferSize,
  }) {
    _keepAliveLink = ref.keepAlive();
    ref.onDispose(() {
      print('disposing WlSurfaceStateProvider $surfaceId');
    });

    state = WlSurface(
      role: role,
      textureId: textureId,
      surfacePosition: Offset(
        bufferDelta?.dx ?? 0.0,
        bufferDelta?.dy ?? 0.0,
      ),
      surfaceSize: Size(
        bufferSize?.width ?? 0.0,
        bufferSize?.height ?? 0.0,
      ),
      scale: scale,
      subsurfacesBelow: subsurfacesBelow,
      subsurfacesAbove: subsurfacesAbove,
      inputRegion: inputRegion,
      surfaceId: surfaceId,
    );
  }

  void commit({
    required SurfaceRole role,
    required TextureId textureId,
    required Offset surfacePosition,
    required Size surfaceSize,
    required int scale,
    required List<int> subsurfacesBelow,
    required List<int> subsurfacesAbove,
    required Rect inputRegion,
  }) {
    state = state.copyWith(
      role: role,
      textureId: textureId,
      surfacePosition: surfacePosition,
      surfaceSize: surfaceSize,
      scale: scale,
      subsurfacesBelow: subsurfacesBelow,
      subsurfacesAbove: subsurfacesAbove,
      inputRegion: inputRegion,
    );
  }

  void dispose() {
    _keepAliveLink.close();
  }
}
