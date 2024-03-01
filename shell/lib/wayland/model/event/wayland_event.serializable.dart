import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/event/commit_surface/commit_surface.serializable.dart';
import 'package:shell/wayland/model/event/destroy_popup/destroy_popup.serializable.dart';
import 'package:shell/wayland/model/event/destroy_subsurface/destroy_subsurface.serializable.dart';
import 'package:shell/wayland/model/event/destroy_surface/destroy_surface.serializable.dart';
import 'package:shell/wayland/model/event/destroy_toplevel/destroy_toplevel.serializable.dart';
import 'package:shell/wayland/model/event/destroy_xdg_surface/destroy_xdg_surface.serializable.dart';
import 'package:shell/wayland/model/event/interactive_move/interactive_move.serializable.dart';
import 'package:shell/wayland/model/event/interactive_resize/interactive_resize.serializable.dart';
import 'package:shell/wayland/model/event/monitor_layout_changed/monitor_layout_changed.serializable.dart';
import 'package:shell/wayland/model/event/new_popup/new_popup.serializable.dart';
import 'package:shell/wayland/model/event/new_subsurface/new_subsurface.serializable.dart';
import 'package:shell/wayland/model/event/new_surface/new_surface.serializable.dart';
import 'package:shell/wayland/model/event/new_toplevel/new_toplevel.serializable.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'wayland_event.serializable.freezed.dart';

part 'wayland_event.serializable.g.dart';

/// Model for WaylandEvent
@Freezed(
  unionKey: 'method',
  unionValueCase: FreezedUnionCase.snake,
)
class WaylandEvent with _$WaylandEvent implements WaylandInteraction {
  /// New Surface Event
  /// This event is sent when the a client creates a new surface.
  const factory WaylandEvent.newSurface({
    required String method,
    required NewSurfaceMessage message,
  }) = NewSurfaceEvent;

  /// New Subsurface Event
  /// This event is sent when the a client creates a new surface.
  const factory WaylandEvent.newSubsurface({
    required String method,
    required NewSubsurfaceMessage message,
  }) = NewSubsurfaceEvent;

  /// New Toplevel Event
  /// This event is sent when the a client creates a new toplevel.
  const factory WaylandEvent.newToplevel({
    required String method,
    required NewToplevelMessage message,
  }) = NewToplevelEvent;

  /// New Popup Event
  /// This event is sent when the a client creates a new popup.
  const factory WaylandEvent.newPopup({
    required String method,
    required NewPopupMessage message,
  }) = NewPopupEvent;

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

  /// Destroy Subsurface Event
  /// This event is sent when the compositor destroys a subsurface.
  const factory WaylandEvent.destroySubsurface({
    required String method,
    required DestroySubsurfaceMessage message,
  }) = DestroySubsurfaceEvent;

  /// Destroy XdgSurface Event
  /// This event is sent when the compositor destroys an XDG surface.
  const factory WaylandEvent.destroyXdgSurface({
    required String method,
    required DestroyXdgSurfaceMessage message,
  }) = DestroyXdgSurfaceEvent;

  /// Destroy Toplevel Event
  /// This event is sent when the compositor destroys a toplevel.
  const factory WaylandEvent.destroyToplevel({
    required String method,
    required DestroyToplevelMessage message,
  }) = DestroyToplevelEvent;

  /// Destroy Popup Event
  /// This event is sent when the compositor destroys a popup.
  const factory WaylandEvent.destroyPopup({
    required String method,
    required DestroyPopupMessage message,
  }) = DestroyPopupEvent;

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

  /// Monitor Layout Changed Event
  /// This event is sent when the the user plugs or unplugs a monitor.
  const factory WaylandEvent.monitorLayoutChanged({
    required String method,
    required MonitorLayoutChangedMessage message,
  }) = MonitorLayoutChangedEvent;

  /// Creates a new [WaylandEvent] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [WaylandEvent] instance.
  factory WaylandEvent.fromJson(Map<String, dynamic> json) =>
      _$WaylandEventFromJson(json);
}
