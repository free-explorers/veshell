import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/platform_api.dart';
import 'package:zenith/ui/common/state/subsurface_state.dart';
import 'package:zenith/ui/common/state/xdg_surface_state.dart';
import 'package:zenith/ui/common/surface.dart';

part '../../../generated/ui/common/state/surface_state.freezed.dart';
part '../../../generated/ui/common/state/surface_state.g.dart';

@Riverpod(keepAlive: true)
Surface surfaceWidget(SurfaceWidgetRef ref, int viewId) {
  return Surface(
    key: ref.watch(surfaceStatesProvider(viewId).select((state) => state.widgetKey)),
    viewId: viewId,
  );
}

@freezed
class SurfaceState with _$SurfaceState {
  const factory SurfaceState({
    required SurfaceRole role,
    required int viewId,
    required TextureId textureId,
    required TextureId oldTextureId,
    required Offset surfacePosition,
    required Size surfaceSize,
    required double scale,
    required GlobalKey widgetKey,
    required GlobalKey textureKey,
    required List<int> subsurfacesBelow,
    required List<int> subsurfacesAbove,
    required Rect inputRegion,
  }) = _SurfaceState;
}

@Riverpod(keepAlive: true)
class SurfaceStates extends _$SurfaceStates {
  @override
  SurfaceState build(int viewId) {
    return SurfaceState(
      role: SurfaceRole.none,
      viewId: viewId,
      textureId: TextureId(-1),
      oldTextureId: TextureId(-1),
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
    final platform = ref.read(platformApiProvider.notifier);

    assert(textureId != state.oldTextureId);

    TextureId oldTexture = state.oldTextureId;
    TextureId currentTexture = state.textureId;

    if (textureId != currentTexture) {
      if (oldTexture.value != -1) {
        platform.textureFinalizer.detach(oldTexture);
      }
      oldTexture = currentTexture;
      currentTexture = textureId;
    }

    print("new texture ${textureId.value} for $viewId");

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

  void dispose() {
    // Cascading dispose of all surface roles.
    switch (state.role) {
      case SurfaceRole.xdgSurface:
        ref.read(xdgSurfaceStatesProvider(viewId).notifier).dispose();
        break;
      case SurfaceRole.subsurface:
        ref.read(subsurfaceStatesProvider(viewId).notifier).dispose();
        break;
      case SurfaceRole.none:
        break;
    }

    ref.invalidate(surfaceWidgetProvider(viewId));

    // This refresh seems very redundant but it's actually needed.
    // Without refresh, the state persists in memory and if a Finalizer attaches to an object
    // inside the state, it will never call its finalization callback.
    final _ = ref.refresh(surfaceStatesProvider(viewId));
    ref.invalidate(surfaceStatesProvider(viewId));
  }
}

enum SurfaceRole {
  none,
  xdgSurface,
  subsurface,
}
