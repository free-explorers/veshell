import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/util/json_converter/offset.dart';
import 'package:shell/shared/util/json_converter/rect.dart';
import 'package:shell/shared/util/json_converter/size.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'commit_surface.serializable.freezed.dart';

part 'commit_surface.serializable.g.dart';

/// Model for CommitSurfaceMessage
@freezed
sealed class CommitSurfaceMessage
    with _$CommitSurfaceMessage
    implements WaylandMessage {
  /// Factory
  factory CommitSurfaceMessage({
    required SurfaceId surfaceId,
    required SurfaceRoleMessage role,
    required TextureId textureId,
    required int scale,
    @RectConverter() required Rect inputRegion,
    required List<int> subsurfacesBelow,
    required List<int> subsurfacesAbove,
    @OffsetConverter() Offset? bufferDelta,
    @SizeConverter() Size? bufferSize,
  }) = _CommitSurfaceMessage;

  factory CommitSurfaceMessage.fromJson(Map<String, dynamic> json) =>
      _$CommitSurfaceMessageFromJson(json);
}

@Freezed(unionKey: 'type')
sealed class SurfaceRoleMessage with _$SurfaceRoleMessage {

  const factory SurfaceRoleMessage.xdgSurface({
    @RectConverter() required Rect? geometry,
    required XdgSurfaceMessage role,
  }) = XdgSurfaceRoleMessage;

  const factory SurfaceRoleMessage.subsurface({
    required SurfaceId parent,
    @OffsetConverter() required Offset position,
  }) = SubsurfaceRoleMessage;

  factory SurfaceRoleMessage.fromJson(Map<String, dynamic> json) =>
      _$SurfaceRoleMessageFromJson(json);
}

@Freezed(unionKey: 'type')
sealed class XdgSurfaceMessage with _$XdgSurfaceMessage {

  const factory XdgSurfaceMessage.xdgToplevel({
    required SurfaceId? parent,
    required String? appId,
    required String? title,
  }) = XdgToplevelMessage;

  const factory XdgSurfaceMessage.xdgPopup({
    required SurfaceId parent,
    @OffsetConverter() required Offset position,
  }) = XdgPopupMessage;

  factory XdgSurfaceMessage.fromJson(Map<String, dynamic> json) =>
      _$XdgSurfaceMessageFromJson(json);
}
