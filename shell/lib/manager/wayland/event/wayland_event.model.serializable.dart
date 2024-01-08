import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/manager/wayland/event/commit_surface/commit_surface.model.serializable.dart';
import 'package:shell/manager/wayland/event/destroy_surface/destroy_surface.model.serializable.dart';
import 'package:shell/manager/wayland/event/interactive_move/interactive_move.model.serializable.dart';
import 'package:shell/manager/wayland/event/interactive_resize/interactive_resize.model.serializable.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';

part 'wayland_event.model.serializable.freezed.dart';
part 'wayland_event.model.serializable.g.dart';

/// Model for WaylandEvent
@Freezed(
  unionKey: 'method',
  unionValueCase: FreezedUnionCase.snake,
)
class WaylandEvent with _$WaylandEvent implements WaylandInteraction {
  /// Commit Surface Event
  /// This event is sent when the compositor commits a surface.
  const factory WaylandEvent.commitSurface({
    required String method,
    required CommitSurfaceMessage message,
  }) = CommitSurfaceEvent;

  /// Destroy Surface Event
  /// This event is sent when the compositor destroys a surface.
  const factory WaylandEvent.destroySurface({
    required String method,
    required DestroySurfaceMessage message,
  }) = DestroySurfaceEvent;

  /// Interactive Move Event
  /// This event is sent when the user starts an interactive move
  const factory WaylandEvent.interactiveMove({
    required String method,
    required InteractiveMoveMessage message,
  }) = InteractiveMoveEvent;

  /// Interactive Resize Event
  /// This event is sent when the user starts an interactive resize
  const factory WaylandEvent.interactiveResize({
    required String method,
    required InteractiveResizeMessage message,
  }) = InteractiveResizeEvent;

  /// Creates a new [WaylandEvent] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [WaylandEvent] instance.
  factory WaylandEvent.fromJson(Map<String, dynamic> json) =>
      _$WaylandEventFromJson(json);
}
