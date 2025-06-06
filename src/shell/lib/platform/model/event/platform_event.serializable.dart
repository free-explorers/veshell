import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/event/commit_surface/commit_surface.serializable.dart';
import 'package:shell/platform/model/event/destroy_subsurface/destroy_subsurface.serializable.dart';
import 'package:shell/platform/model/event/destroy_surface/destroy_surface.serializable.dart';
import 'package:shell/platform/model/event/gesture_swipe/gesture_swipe_begin.serializable.dart';
import 'package:shell/platform/model/event/gesture_swipe/gesture_swipe_end.serializable.dart';
import 'package:shell/platform/model/event/gesture_swipe/gesture_swipe_update.serializable.dart';
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
import 'package:shell/platform/provider/platform_manager.dart';

part 'platform_event.serializable.freezed.dart';
part 'platform_event.serializable.g.dart';

/// Model for PlatformEvent
@Freezed(
  unionKey: 'method',
  unionValueCase: FreezedUnionCase.snake,
)
sealed class PlatformEvent with _$PlatformEvent implements PlatformInteraction {
  /// New Surface Event
  /// This event is sent when the a client creates a new surface.
  const factory PlatformEvent.newSurface({
    required String method,
    required NewSurfaceMessage message,
  }) = NewSurfaceEvent;

  /// New Subsurface Event
  /// This event is sent when the a client creates a new surface.
  const factory PlatformEvent.newSubsurface({
    required String method,
    required NewSubsurfaceMessage message,
  }) = NewSubsurfaceEvent;

  /// New MetaWindow Event
  /// This event is sent when the a client creates a new meta window.
  const factory PlatformEvent.metaWindowCreated({
    required String method,
    required MetaWindowCreatedMessage message,
  }) = MetaWindowCreatedEvent;

  /// MetaWindow Patch Event
  /// This event is sent when the a client patches a meta window.
  const factory PlatformEvent.metaWindowPatch({
    required String method,
    required MetaWindowPatchMessage message,
  }) = MetaWindowPatchEvent;

  /// MetaWindow Removed Event
  /// This event is sent when the a client removes a meta window.
  const factory PlatformEvent.metaWindowRemoved({
    required String method,
    required MetaWindowRemovedMessage message,
  }) = MetaWindowRemovedEvent;

  /// New MetaPopup Event
  /// This event is sent when the a client creates a new meta popup.
  const factory PlatformEvent.metaPopupCreated({
    required String method,
    required MetaPopupCreatedMessage message,
  }) = MetaPopupCreatedEvent;

  /// MetaPopup Patch Event
  /// This event is sent when the a client patches a meta popup.
  const factory PlatformEvent.metaPopupPatch({
    required String method,
    required MetaPopupPatchMessage message,
  }) = MetaPopupPatchEvent;

  /// MetaPopup Removed Event
  /// This event is sent when the a client removes a meta popup.
  const factory PlatformEvent.metaPopupRemoved({
    required String method,
    required MetaPopupRemovedMessage message,
  }) = MetaPopupRemovedEvent;

  /// Commit Surface Event
  /// This event is sent when the compositor commits a surface.
  const factory PlatformEvent.commitSurface({
    required String method,
    required CommitSurfaceMessage message,
  }) = CommitSurfaceEvent;

  /// Destroy Surface Event
  /// This event is sent when the compositor destroys a surface.
  const factory PlatformEvent.destroySurface({
    required String method,
    required DestroySurfaceMessage message,
  }) = DestroySurfaceEvent;

  /// Destroy Subsurface Event
  /// This event is sent when the compositor destroys a subsurface.
  const factory PlatformEvent.destroySubsurface({
    required String method,
    required DestroySubsurfaceMessage message,
  }) = DestroySubsurfaceEvent;

  /// Interactive Move Event
  /// This event is sent when the user starts an interactive move
  const factory PlatformEvent.interactiveMove({
    required String method,
    required InteractiveMoveMessage message,
  }) = InteractiveMoveEvent;

  /// Interactive Resize Event
  /// This event is sent when the user starts an interactive resize
  const factory PlatformEvent.interactiveResize({
    required String method,
    required InteractiveResizeMessage message,
  }) = InteractiveResizeEvent;

  /// Monitor Layout Changed Event
  /// This event is sent when the the user plugs or unplugs a monitor.
  const factory PlatformEvent.monitorLayoutChanged({
    required String method,
    required MonitorLayoutChangedMessage message,
  }) = MonitorLayoutChangedEvent;

  /// Set Environment Variables Event
  /// This event is sent when the embedder wants to set environment variables.
  const factory PlatformEvent.setEnvironmentVariables({
    required String method,
    required SetEnvironmentVariablesMessage message,
  }) = SetEnvironmentVariablesEvent;

  /// Gesture Swipe Begin Event
  /// This event is sent when the user performs a swipe gesture.
  const factory PlatformEvent.gestureSwipeBegin({
    required String method,
    required GestureSwipeBeginMessage message,
  }) = GestureSwipeBeginEvent;

  /// Gesture Swipe Update Event
  /// This event is sent when the user performs a swipe gesture.
  const factory PlatformEvent.gestureSwipeUpdate({
    required String method,
    required GestureSwipeUpdateMessage message,
  }) = GestureSwipeUpdateEvent;

  /// Gesture Swipe End Event
  /// This event is sent when the user performs a swipe gesture.
  const factory PlatformEvent.gestureSwipeEnd({
    required String method,
    required GestureSwipeEndMessage message,
  }) = GestureSwipeEndEvent;

  /// Creates a new [PlatformEvent] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [PlatformEvent] instance.
  factory PlatformEvent.fromJson(Map<String, dynamic> json) =>
      _$PlatformEventFromJson(json);
}
