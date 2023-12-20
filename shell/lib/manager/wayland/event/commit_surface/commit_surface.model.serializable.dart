import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';
import 'package:shell/shared/util/json_converter/offset.dart';
import 'package:shell/shared/util/json_converter/rect.dart';
import 'package:shell/shared/util/json_converter/size.dart';

part 'commit_surface.model.serializable.freezed.dart';
part 'commit_surface.model.serializable.g.dart';

/// Model for Surface
@freezed
class SurfaceMessage with _$SurfaceMessage {
  /// Factory
  factory SurfaceMessage({
    required SurfaceId surfaceId,
    required SurfaceRole role,
    required TextureId textureId,
    required int scale,
    @RectConverter() required Rect inputRegion,
    required List<int> subsurfacesBelow,
    required List<int> subsurfacesAbove,
    @OffsetConverter() Offset? bufferDelta,
    @SizeConverter() Size? bufferSize,
  }) = _SurfaceMessage;

  factory SurfaceMessage.fromJson(Map<String, dynamic> json) =>
      _$SurfaceMessageFromJson(json);
}

/// Model for CommitSurfaceEvent
@Freezed(
  unionKey: 'role',
  unionValueCase: FreezedUnionCase.snake,
  fallbackUnion: 'simple',
)
class CommitSurfaceMessage
    with _$CommitSurfaceMessage
    implements WaylandMessage {
  /// Factory for xdgToplevel
  const factory CommitSurfaceMessage.simple({
    required SurfaceId surfaceId,
    required SurfaceRole role,
    SurfaceMessage? surface,
  }) = SimpleCommitSurfaceMessage;

  /// Factory for xdgToplevel
  const factory CommitSurfaceMessage.xdgToplevel({
    required SurfaceId surfaceId,
    required SurfaceMessage surface,
    required SurfaceRole role,
    String? appId,
    String? title,
    SurfaceId? parentSurfaceId,
    @RectConverter() Rect? geometry,
  }) = XdgToplevelCommitSurfaceMessage;

  /// Factory for xdgPopup
  const factory CommitSurfaceMessage.xdgPopup({
    required SurfaceId surfaceId,
    required SurfaceMessage surface,
    required SurfaceRole role,
    required SurfaceId parentSurfaceId,
    @RectConverter() Rect? geometry,
  }) = XdgPopupCommitSurfaceMessage;

  /// Factory for Subsurface
  const factory CommitSurfaceMessage.subsurface({
    required SurfaceId surfaceId,
    required SurfaceMessage surface,
    required SurfaceRole role,
    required SurfaceId parentSurfaceId,
    @OffsetConverter() required Offset position,
  }) = SubsurfaceCommitSurfaceMessage;

  factory CommitSurfaceMessage.fromJson(Map<String, dynamic> json) =>
      _$CommitSurfaceMessageFromJson(json);
}
