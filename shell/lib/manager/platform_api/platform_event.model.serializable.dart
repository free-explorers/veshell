import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/util/json_converter/offset.dart';
import 'package:shell/shared/util/json_converter/rect.dart';
import 'package:shell/shared/util/json_converter/size.dart';

part 'platform_event.model.serializable.freezed.dart';
part 'platform_event.model.serializable.g.dart';

enum SurfaceRole {
  @JsonValue(0)
  none,
  @JsonValue('xdg_toplevel')
  xdgTopLevel,
  @JsonValue('xdg_popup')
  xdgPopup,
  @JsonValue('subsurface')
  subsurface,
}

/// Model for Surface
@freezed
class SurfaceMessage with _$SurfaceMessage {
  /// Factory
  factory SurfaceMessage({
    required int surfaceId,
    required SurfaceRole role,
    required int textureId,
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

/// Model for XdgSurface
@freezed
class XdgSurface with _$XdgSurface {
  /// Factory
  factory XdgSurface({
    required SurfaceRole role,
    required int x,
    required int y,
    required int width,
    required int height,
  }) = _XdgSurface;

  factory XdgSurface.fromJson(Map<String, dynamic> json) =>
      _$XdgSurfaceFromJson(json);
}

/// Model for XdgSurface
@freezed
class XdgPopup with _$XdgPopup {
  /// Factory
  factory XdgPopup({
    required int parentId,
    required int x,
    required int y,
    required int width,
    required int height,
  }) = _XdgPopup;

  factory XdgPopup.fromJson(Map<String, dynamic> json) =>
      _$XdgPopupFromJson(json);
}

/// Model for Subsurface
@freezed
class Subsurface with _$Subsurface {
  /// Factory
  factory Subsurface({
    required int x,
    required int y,
  }) = _Subsurface;

  factory Subsurface.fromJson(Map<String, dynamic> json) =>
      _$SubsurfaceFromJson(json);
}

/// Model for CommitSurfaceEvent
@Freezed(unionKey: 'role', unionValueCase: FreezedUnionCase.snake)
class CommitSurfaceEvent with _$CommitSurfaceEvent {
  /// Factory for xdgToplevel
  factory CommitSurfaceEvent({
    required int surfaceId,
    required SurfaceMessage surface,
    required SurfaceRole role,
  }) = SimpleCommitSurfaceEvent;

  /// Factory for xdgToplevel
  factory CommitSurfaceEvent.xdgToplevel({
    required int surfaceId,
    required SurfaceMessage surface,
    required SurfaceRole role,
    String? appId,
    String? title,
    int? parentSurfaceId,
    @RectConverter() Rect? geometry,
  }) = XdgToplevelCommitSurfaceEvent;

  /// Factory for xdgPopup
  factory CommitSurfaceEvent.xdgPopup({
    required int surfaceId,
    required SurfaceMessage surface,
    required SurfaceRole role,
    required int parentSurfaceId,
    @RectConverter() Rect? geometry,
  }) = XdgPopupCommitSurfaceEvent;

  /// Factory for Subsurface
  factory CommitSurfaceEvent.subsurface({
    required int surfaceId,
    required SurfaceMessage surface,
    required SurfaceRole role,
    required int parentSurfaceId,
    @OffsetConverter() required Offset position,
  }) = SubsurfaceCommitSurfaceEvent;

  factory CommitSurfaceEvent.fromJson(Map<String, dynamic> json) =>
      _$CommitSurfaceEventFromJson(json);
}

/// Model for TextInputEvent
@Freezed(unionKey: 'type', unionValueCase: FreezedUnionCase.snake)
class TextInputEvent with _$TextInputEvent {
  TextInputEvent._();

  /// Factory for EnableTextInputEvent
  factory TextInputEvent.enable({required int surfaceId}) =
      EnableTextInputEvent;

  /// Factory for DisableTextInputEvent
  factory TextInputEvent.disable({required int surfaceId}) =
      DisableTextInputEvent;

  /// Factory for CommitTextInputEvent
  factory TextInputEvent.commit({required int surfaceId}) =
      CommitTextInputEvent;

  factory TextInputEvent.fromJson(Map<String, dynamic> json) =>
      _$TextInputEventFromJson(json);
}

/// Model for InteractiveMoveEvent
@freezed
class InteractiveMoveEvent with _$InteractiveMoveEvent {
  /// Factory
  factory InteractiveMoveEvent({
    required int surfaceId,
  }) = _InteractiveMoveEvent;

  factory InteractiveMoveEvent.fromJson(Map<String, dynamic> json) =>
      _$InteractiveMoveEventFromJson(json);
}

/// Model for InteractiveResizeEvent
@freezed
class InteractiveResizeEvent with _$InteractiveResizeEvent {
  /// Factory
  factory InteractiveResizeEvent({
    required int surfaceId,
    required int edge,
  }) = _InteractiveResizeEvent;

  factory InteractiveResizeEvent.fromJson(Map<String, dynamic> json) =>
      _$InteractiveResizeEventFromJson(json);
}

/// Model for SetTitleEvent
@freezed
class SetTitleEvent with _$SetTitleEvent {
  /// Factory
  factory SetTitleEvent({
    required int surfaceId,
    required String title,
  }) = _SetTitleEvent;

  factory SetTitleEvent.fromJson(Map<String, dynamic> json) =>
      _$SetTitleEventFromJson(json);
}

/// Model for SetAppIdEvent
@freezed
class SetAppIdEvent with _$SetAppIdEvent {
  /// Factory
  factory SetAppIdEvent({
    required int surfaceId,
    required String appId,
  }) = _SetAppIdEvent;

  factory SetAppIdEvent.fromJson(Map<String, dynamic> json) =>
      _$SetAppIdEventFromJson(json);
}

/// Model for RequestMaxmizeEvent
@freezed
class RequestMaxmizeEvent with _$RequestMaxmizeEvent {
  /// Factory
  factory RequestMaxmizeEvent({
    required int surfaceId,
    required bool maximize,
  }) = _RequestMaxmizeEvent;

  factory RequestMaxmizeEvent.fromJson(Map<String, dynamic> json) =>
      _$RequestMaxmizeEventFromJson(json);
}

/// Model for DestroySurfaceEvent
@freezed
class DestroySurfaceEvent with _$DestroySurfaceEvent {
  /// Factory
  factory DestroySurfaceEvent({
    required int surfaceId,
  }) = _DestroySurfaceEvent;

  factory DestroySurfaceEvent.fromJson(Map<String, dynamic> json) =>
      _$DestroySurfaceEventFromJson(json);
}
