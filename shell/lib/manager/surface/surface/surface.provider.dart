import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/manager/platform_api/platform_event.model.serializable.dart';
import 'package:shell/manager/surface/subsurface/subsurface.provider.dart';
import 'package:shell/manager/surface/surface/surface.dart';
import 'package:shell/manager/surface/surface/surface.model.dart';
import 'package:shell/manager/surface/xdg_surface/xdg_surface.provider.dart';

part 'surface.provider.g.dart';

@Riverpod(keepAlive: true)
SurfaceWidget surfaceWidget(SurfaceWidgetRef ref, int surfaceId) {
  return SurfaceWidget(
    key: ref.watch(
      surfaceStatesProvider(surfaceId).select((state) => state.widgetKey),
    ),
    surfaceId: surfaceId,
  );
}

@Riverpod(keepAlive: true)
class SurfaceStates extends _$SurfaceStates {
  @override
  SurfaceState build(int surfaceId) {
    return SurfaceState(
      role: SurfaceRole.none,
      surfaceId: surfaceId,
      textureId: -1,
      oldTextureId: -1,
      surfacePosition: Offset.zero,
      surfaceSize: Size.zero,
      scale: 1,
      widgetKey: GlobalKey(),
      textureKey: GlobalKey(),
      subsurfacesBelow: [],
      subsurfacesAbove: [],
      inputRegion: Rect.zero,
    );
  }

  void commit({
    required SurfaceRole role,
    required TextureId textureId,
    required Offset surfacePosition,
    required Size surfaceSize,
    required double scale,
    required List<int> subsurfacesBelow,
    required List<int> subsurfacesAbove,
    required Rect inputRegion,
  }) {
    // assert(textureId != state.oldTextureId);

    var oldTexture = state.oldTextureId;
    var currentTexture = state.textureId;

    if (textureId != currentTexture) {
      oldTexture = currentTexture;
      currentTexture = textureId;
    }

    state = state.copyWith(
      role: role,
      textureId: currentTexture,
      oldTextureId: oldTexture,
      surfacePosition: surfacePosition,
      surfaceSize: surfaceSize,
      scale: scale,
      subsurfacesBelow: subsurfacesBelow,
      subsurfacesAbove: subsurfacesAbove,
      inputRegion: inputRegion,
    );
  }

  void unmap() {
    state = state.copyWith(
      role: SurfaceRole.none,
    );
  }

  void dispose() {
    // Cascading dispose of all surface roles.
    switch (state.role) {
      case SurfaceRole.xdgTopLevel:
      case SurfaceRole.xdgPopup:
        ref.read(xdgSurfaceStatesProvider(surfaceId).notifier).dispose();
      case SurfaceRole.subsurface:
        ref.read(subsurfaceStatesProvider(surfaceId).notifier).dispose();
      case SurfaceRole.none:
      case SurfaceRole.cursorImage:
        break;
    }

    ref
      ..invalidate(surfaceWidgetProvider(surfaceId))
      ..invalidateSelf();
  }
}
