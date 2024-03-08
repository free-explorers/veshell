import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/util/json_converter/rect.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/model/x11_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'map_x11_surface.serializable.freezed.dart';

part 'map_x11_surface.serializable.g.dart';

/// Model for MapX11SurfaceMessage
@freezed
sealed class MapX11SurfaceMessage
    with _$MapX11SurfaceMessage
    implements WaylandMessage {
  /// Factory
  factory MapX11SurfaceMessage({
    required X11SurfaceId x11SurfaceId,
    required SurfaceId surfaceId,
    required bool overrideRedirect,
    @RectConverter() required Rect geometry,
    required X11SurfaceId? parent,
  }) = _MapX11SurfaceMessage;

  factory MapX11SurfaceMessage.fromJson(Map<String, dynamic> json) =>
      _$MapX11SurfaceMessageFromJson(json);
}
