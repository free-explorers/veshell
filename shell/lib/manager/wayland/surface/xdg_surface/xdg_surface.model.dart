import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';

part 'xdg_surface.model.freezed.dart';

@freezed
class XdgSurface with _$XdgSurface {
  /// Factory for xdgToplevel
  const factory XdgSurface.xdgToplevel({
    required SurfaceId surfaceId,
    required Rect geometry,
    required String appId,
    required String title,
    SurfaceId? parentSurfaceId,
  }) = XdgToplevelSurface;

  /// Factory for xdgPopup
  const factory XdgSurface.xdgPopup({
    required SurfaceId surfaceId,
    required SurfaceId parentSurfaceId,
    required Rect geometry,
  }) = XdgPopupSurface;
}
