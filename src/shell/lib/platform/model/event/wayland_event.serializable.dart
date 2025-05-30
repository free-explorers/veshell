import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/event/commit_surface/commit_surface.serializable.dart';
import 'package:shell/platform/model/event/destroy_subsurface/destroy_subsurface.serializable.dart';
import 'package:shell/platform/model/event/destroy_surface/destroy_surface.serializable.dart';
import 'package:shell/platform/model/event/interactive_move/interactive_move.serializable.dart';
import 'package:shell/platform/model/event/interactive_resize/interactive_resize.serializable.dart';
import 'package:shell/platform/model/event/meta_popup_created/meta_popup_created.serializable.dart';
import 'package:shell/platform/model/event/meta_popup_patches/meta_popup_patches.serializable.dart';
import 'package:shell/platform/model/event/meta_popup_removed/meta_popup_removed.serializable.dart';
import 'package:shell/platform/model/event/meta_window_created/meta_window_created.serializable.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/platform/model/event/meta_window_removed/meta_window_removed.serializable.dart';
import 'package:shell/platform/model/event/monitor_layout_changed/monitor_layout_changed.serializable.dart';
import 'package:shell/platform/model/event/new_subsurface/new_subsurface.serializable.dart';
import 'package:shell/platform/model/event/new_surface/new_surface.serializable.dart';
import 'package:shell/platform/model/event/set_environment_variables/set_environment_variables.serializable.dart';
import 'package:shell/platform/provider/wayland.manager.dart';

part 'wayland_event.serializable.freezed.dart';
part 'wayland_event.serializable.g.dart';

/// Model for WaylandEvent
@Freezed(
  unionKey: 'method',
  unionValueCase: FreezedUnionCase.snake,
)
sealed class WaylandEvent with _$WaylandEvent implements WaylandInteraction {
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

  /// New MetaWindow Event
  /// This event is sent when the a client creates a new meta window.
  const factory WaylandEvent.metaWindowCreated({
    required String method,
    required MetaWindowCreatedMessage message,
  }) = MetaWindowCreatedEvent;

  /// MetaWindow Patch Event
  /// This event is sent when the a client patches a meta window.
  const factory WaylandEvent.metaWindowPatch({
    required String method,
    required MetaWindowPatchMessage message,
  }) = MetaWindowPatchEvent;

  /// MetaWindow Removed Event
  /// This event is sent when the a client removes a meta window.
  const factory WaylandEvent.metaWindowRemoved({
    required String method,
    required MetaWindowRemovedMessage message,
  }) = MetaWindowRemovedEvent;

  /// New MetaPopup Event
  /// This event is sent when the a client creates a new meta popup.
  const factory WaylandEvent.metaPopupCreated({
    required String method,
    required MetaPopupCreatedMessage message,
  }) = MetaPopupCreatedEvent;

  /// MetaPopup Patch Event
  /// This event is sent when the a client patches a meta popup.
  const factory WaylandEvent.metaPopupPatch({
    required String method,
    required MetaPopupPatchMessage message,
  }) = MetaPopupPatchEvent;

  /// MetaPopup Removed Event
  /// This event is sent when the a client removes a meta popup.
  const factory WaylandEvent.metaPopupRemoved({
    required String method,
    required MetaPopupRemovedMessage message,
  }) = MetaPopupRemovedEvent;

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
