import 'package:freezed_annotation/freezed_annotation.dart';

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
