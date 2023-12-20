import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/manager/wayland/event/commit_surface/commit_surface.model.serializable.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';

part 'wl_surface.provider.g.dart';

@riverpod
class WlSurfaceState extends _$WlSurfaceState {
  late final KeepAliveLink _keepAliveLink;
  @override
  WlSurface build(SurfaceId surfaceId) {
    throw Exception('WlSurface not yet initialized');
  }

  void initialize(CommitSurfaceMessage message) {
    _keepAliveLink = ref.keepAlive();
    ref.onDispose(() {
      print('disposing WlSurfaceStateProvider $surfaceId');
    });
    final surface = message.surface!;
    state = WlSurface(
      role: message.role,
      textureId: surface.textureId,
      surfacePosition: Offset(
        surface.bufferDelta?.dx ?? 0.0,
        surface.bufferDelta?.dy ?? 0.0,
      ),
      surfaceSize: Size(
        surface.bufferSize?.width ?? 0.0,
        surface.bufferSize?.height ?? 0.0,
      ),
      scale: surface.scale,
      subsurfacesBelow: surface.subsurfacesBelow,
      subsurfacesAbove: surface.subsurfacesAbove,
      inputRegion: surface.inputRegion,
      surfaceId: message.surfaceId,
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
    // assert(textureId != state.oldTextureId);

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
