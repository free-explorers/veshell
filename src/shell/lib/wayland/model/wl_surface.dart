import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wl_surface.freezed.dart';

typedef TextureId = int;
typedef SurfaceId = int;

enum SurfaceRole {
  xdgToplevel,
  xdgPopup,
  subsurface,
  x11Surface,
}

@freezed
abstract class SurfaceTexture with _$SurfaceTexture {
  const factory SurfaceTexture({
    required TextureId id,
    required Size size,
  }) = _SurfaceTexture;
}

@freezed
abstract class WlSurface with _$WlSurface {
  const factory WlSurface({
    required SurfaceId surfaceId,
    required SurfaceRole? role,
    required SurfaceTexture? texture,
    required int scale,
    required IList<int> subsurfacesBelow,
    required IList<int> subsurfacesAbove,
    required Rect inputRegion,
  }) = _WlSurface;
}
