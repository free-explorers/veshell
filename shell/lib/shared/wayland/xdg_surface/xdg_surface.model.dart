import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/manager/platform_api/platform_event.model.serializable.dart';

part 'xdg_surface.model.freezed.dart';

@freezed
class XdgSurfaceState with _$XdgSurfaceState {
  const factory XdgSurfaceState({
    required bool mapped,
    required SurfaceRole role,
    required Rect visibleBounds,
    required GlobalKey widgetKey,
    required List<int> popups,
  }) = _XdgSurfaceState;
}
