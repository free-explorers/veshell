import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wl_surface.model.freezed.dart';

typedef TextureId = int;
typedef SurfaceId = int;

enum SurfaceRole {
  @JsonValue(0)
  none,
  @JsonValue('xdg_toplevel')
  xdgTopLevel,
  @JsonValue('xdg_popup')
  xdgPopup,
  @JsonValue('subsurface')
  subsurface,
  @JsonValue('cursor_image')
  cursorImage
}

@freezed
class WlSurface with _$WlSurface {
  const factory WlSurface({
    required SurfaceRole role,
    required SurfaceId surfaceId,
    required TextureId textureId,
    required Offset surfacePosition,
    required Size surfaceSize,
    required int scale,
    required List<int> subsurfacesBelow,
    required List<int> subsurfacesAbove,
    required Rect inputRegion,
  }) = _WlSurface;
}
