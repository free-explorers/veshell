import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/wayland/xdg_surface/xdg_surface.model.dart';
import 'package:shell/shared/wayland/xdg_toplevel/xdg_toplevel.model.dart';

part 'platform_event.model.serializable.freezed.dart';
part 'platform_event.model.serializable.g.dart';

/// Model for InputRegion
@freezed
class InputRegion with _$InputRegion {
  /// Factory
  factory InputRegion({
    required int x1,
    required int x2,
    required int y1,
    required int y2,
    required,
  }) = _InputRegion;

  factory InputRegion.fromJson(Map<String, dynamic> json) =>
      _$InputRegionFromJson(json);
}

enum SurfaceRole {
  @JsonValue(0)
  none,
  @JsonValue(1)
  xdgSurface,
  @JsonValue(2)
  subsurface,
}

/// Model for Surface
@freezed
class SurfaceEvent with _$SurfaceEvent {
  /// Factory
  factory SurfaceEvent({
    required SurfaceRole role,
    required int textureId,
    required int x,
    required int y,
    required int width,
    required int height,
    required int scale,
    required InputRegion inputRegion,
    required List<int> subsurfacesBelow,
    required List<int> subsurfacesAbove,
  }) = _SurfaceEvent;

  factory SurfaceEvent.fromJson(Map<String, dynamic> json) =>
      _$SurfaceEventFromJson(json);
}

/// Model for XdgSurface
@freezed
class XdgSurface with _$XdgSurface {
  /// Factory
  factory XdgSurface({
    required XdgSurfaceRole role,
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
@freezed
class CommitSurfaceEvent with _$CommitSurfaceEvent {
  /// Factory
  factory CommitSurfaceEvent({
    required int surfaceId,
    required SurfaceEvent surface,
    XdgSurface? xdgSurface,
    XdgPopup? xdgPopup,
    Subsurface? subsurface,
    ToplevelDecoration? toplevelDecoration,
    String? toplevelTitle,
    String? toplevelAppId,
  }) = _CommitSurfaceEvent;

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
