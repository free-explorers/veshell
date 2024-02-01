import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/event/commit_surface/commit_surface.serializable.dart';
import 'package:shell/wayland/model/event/destroy_surface/destroy_surface.serializable.dart';
import 'package:shell/wayland/model/event/interactive_move/interactive_move.serializable.dart';
import 'package:shell/wayland/model/event/interactive_resize/interactive_resize.serializable.dart';
import 'package:shell/wayland/model/event/output_layout_changed/output_layout_changed.serializable.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'wayland_event.serializable.freezed.dart';
part 'wayland_event.serializable.g.dart';

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

  /// Interactive Resize Event
  /// This event is sent when the user starts an interactive resize
  const factory WaylandEvent.outputLayoutChanged({
    required String method,
    required OutputLayoutChangedMessage message,
  }) = OutputLayoutChangedEvent;

  /// Creates a new [WaylandEvent] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [WaylandEvent] instance.
  factory WaylandEvent.fromJson(Map<String, dynamic> json) =>
      _$WaylandEventFromJson(json);
}
