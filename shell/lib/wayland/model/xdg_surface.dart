import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'xdg_surface.freezed.dart';

@freezed
class XdgSurface with _$XdgSurface {
  /// Factory for xdgPopup
  const factory XdgSurface({
    required Rect? geometry,
    required List<SurfaceId> popups,
  }) = _XdgSurface;
}
