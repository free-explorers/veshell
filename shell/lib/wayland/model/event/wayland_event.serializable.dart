import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/event/app_id_changed/app_id_changed.serializable.dart';
import 'package:shell/wayland/model/event/commit_surface/commit_surface.serializable.dart';
import 'package:shell/wayland/model/event/destroy_popup/destroy_popup.serializable.dart';
import 'package:shell/wayland/model/event/destroy_subsurface/destroy_subsurface.serializable.dart';
import 'package:shell/wayland/model/event/destroy_surface/destroy_surface.serializable.dart';
import 'package:shell/wayland/model/event/destroy_toplevel/destroy_toplevel.serializable.dart';
import 'package:shell/wayland/model/event/destroy_x11_surface/destroy_x11_surface.serializable.dart';
import 'package:shell/wayland/model/event/destroy_xdg_surface/destroy_xdg_surface.serializable.dart';
import 'package:shell/wayland/model/event/interactive_move/interactive_move.serializable.dart';
import 'package:shell/wayland/model/event/interactive_resize/interactive_resize.serializable.dart';
import 'package:shell/wayland/model/event/map_x11_surface/map_x11_surface.serializable.dart';
import 'package:shell/wayland/model/event/monitor_layout_changed/monitor_layout_changed.serializable.dart';
import 'package:shell/wayland/model/event/new_popup/new_popup.serializable.dart';
import 'package:shell/wayland/model/event/new_subsurface/new_subsurface.serializable.dart';
import 'package:shell/wayland/model/event/new_surface/new_surface.serializable.dart';
import 'package:shell/wayland/model/event/new_toplevel/new_toplevel.serializable.dart';
import 'package:shell/wayland/model/event/new_x11_surface/new_x11_surface.serializable.dart';
import 'package:shell/wayland/model/event/set_environment_variables/set_environment_variables.serializable.dart';
import 'package:shell/wayland/model/event/surface_associated/surface_associated.serializable.dart';
import 'package:shell/wayland/model/event/title_changed/title_changed.serializable.dart';
import 'package:shell/wayland/model/event/unmap_x11_surface/unmap_x11_surface.serializable.dart';
import 'package:shell/wayland/model/event/x11_properties_changed/x11_properties_changed.serializable.dart';
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

  /// New X11 surface Event
  /// This event is sent when the a client creates a new X11 surface.
  const factory WaylandEvent.newX11Surface({
    required String method,
    required NewX11SurfaceMessage message,
  }) = NewX11SurfaceEvent;

  /// Commit Surface Event
  /// This event is sent when the compositor commits a surface.
  const factory WaylandEvent.commitSurface({
    required String method,
    required CommitSurfaceMessage message,
  }) = CommitSurfaceEvent;

  /// Map X11 surface Event
  /// This event is sent when the compositor maps an X11 surface.
  const factory WaylandEvent.mapX11Surface({
    required String method,
    required MapX11SurfaceMessage message,
  }) = MapX11SurfaceEvent;

  /// Unmap X11 surface Event
  /// This event is sent when the compositor maps an X11 surface.
  const factory WaylandEvent.unmapX11Surface({
    required String method,
    required UnmapX11SurfaceMessage message,
  }) = UnmapX11SurfaceEvent;

  /// X11 Properties Changed Event
  /// This event is sent when the X11 properties of a surface change.
  const factory WaylandEvent.x11PropertiesChanged({
    required String method,
    required X11PropertiesChangedMessage message,
  }) = X11PropertiesChangedEvent;

  /// Surface Associated Event
  /// This event is sent when the compositor associates a surface with an X11 surface.
  const factory WaylandEvent.surfaceAssociated({
    required String method,
    required SurfaceAssociatedMessage message,
  }) = SurfaceAssociatedEvent;

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

  /// Destroy X11 surface Event
  /// This event is sent when the compositor destroys an X11 surface.
  const factory WaylandEvent.destroyX11Surface({
    required String method,
    required DestroyX11SurfaceMessage message,
  }) = DestroyX11SurfaceEvent;

  // Sent when the title of an XDG toplevel changes.
  const factory WaylandEvent.appIdChanged({
    required String method,
    required AppIdChangedMessage message,
  }) = AppIdChangedEvent;

  // Sent when the title of an XDG toplevel changes.
  const factory WaylandEvent.titleChanged({
    required String method,
    required TitleChangedMessage message,
  }) = TitleChangedEvent;

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

  /// Set Environment Variables Event
  /// This event is sent when the embedder wants to set environment variables.
  const factory WaylandEvent.setEnvironmentVariables({
    required String method,
    required SetEnvironmentVariablesMessage message,
  }) = SetEnvironmentVariablesEvent;

  /// Creates a new [WaylandEvent] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [WaylandEvent] instance.
  factory WaylandEvent.fromJson(Map<String, dynamic> json) =>
      _$WaylandEventFromJson(json);
}
