import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/capture/model/screen_cast_active/screen_cast_active.serializable.dart';
import 'package:shell/capture/model/screen_cast_consent/screen_cast_consent.serializable.dart';
import 'package:shell/capture/model/screen_cast_consent_dismissed/screen_cast_consent_dismissed.serializable.dart';
import 'package:shell/capture/model/screen_cast_recording/screen_cast_recording.serializable.dart';
import 'package:shell/capture/model/screen_cast_stopped/screen_cast_stopped.serializable.dart';
import 'package:shell/capture/model/screenshot_prompt/screenshot_prompt.serializable.dart';
import 'package:shell/notification/model/notification_close_requested/notification_close_requested.serializable.dart';
import 'package:shell/notification/model/notification_received/notification_received.serializable.dart';
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
import 'package:shell/platform/model/event/process_info/process_info.serializable.dart';
import 'package:shell/platform/model/event/set_environment_variables/set_environment_variables.serializable.dart';
import 'package:shell/platform/model/event/window_activation_requested/window_activation_requested.serializable.dart';
import 'package:shell/platform/model/event/window_attention_released/window_attention_released.serializable.dart';
import 'package:shell/platform/model/event/window_attention_requested/window_attention_requested.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'platform_event.serializable.freezed.dart';
part 'platform_event.serializable.g.dart';

/// Model for PlatformEvent
@Freezed(unionKey: 'method', unionValueCase: FreezedUnionCase.snake)
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

  /// Process Info Event
  /// Sent when the compositor learns or refreshes the process facts of a pid
  /// (cgroup, Flatpak/Snap id, binary name).
  const factory PlatformEvent.processInfo({
    required String method,
    required ProcessInfoMessage message,
  }) = ProcessInfoEvent;

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

  /// Screen cast consent picker event, sent by the compositor when the
  /// portal opens the trusted picker.
  const factory PlatformEvent.screenCastConsent({
    required String method,
    required ScreenCastConsentMessage message,
  }) = ScreenCastConsentEvent;

  /// Screen cast consent dismissal, sent by the compositor when the flow
  /// closed itself (session request close, frontend loss).
  const factory PlatformEvent.screenCastConsentDismissed({
    required String method,
    required ScreenCastConsentDismissedMessage message,
  }) = ScreenCastConsentDismissedEvent;

  /// Screenshot portal prompt event, sent by the compositor when a
  /// sandboxed app asks the trusted shell to take a screenshot or pick a
  /// color (capture specification section 8.4).
  const factory PlatformEvent.screenshotPrompt({
    required String method,
    required ScreenshotPromptMessage message,
  }) = ScreenshotPromptEvent;

  /// Screen cast delivery began: the persistent indicator appears.
  const factory PlatformEvent.screenCastActive({
    required String method,
    required ScreenCastActiveMessage message,
  }) = ScreenCastActiveEvent;

  /// Where a live screen cast landed: the MetaWindow it resolved to, or `null`
  /// for an orphan cast the workspace/tile indicators cannot display. Only the
  /// orphan case keeps the persistent indicator bar.
  const factory PlatformEvent.screenCastRecording({
    required String method,
    required ScreenCastRecordingMessage message,
  }) = ScreenCastRecordingEvent;

  /// Screen cast delivery stopped: the persistent indicator hides.
  const factory PlatformEvent.screenCastStopped({
    required String method,
    required ScreenCastStoppedMessage message,
  }) = ScreenCastStoppedEvent;

  /// Notification received: the compositor accepted a `Notify` D-Bus call and
  /// forwards it with the trusted sender pid. The shell assigns the id and
  /// answers with `notification_notify_result`.
  const factory PlatformEvent.notificationReceived({
    required String method,
    required NotificationReceivedMessage message,
  }) = NotificationReceivedEvent;

  /// A client called `CloseNotification`; the shell tears down the live popup.
  const factory PlatformEvent.notificationCloseRequested({
    required String method,
    required NotificationCloseRequestedMessage message,
  }) = NotificationCloseRequestedEvent;

  /// The compositor honored an activation token minted for an invoked
  /// notification action and focused the window: the shell brings it into view
  /// (selecting its workspace and tile), which the compositor cannot do.
  const factory PlatformEvent.windowActivationRequested({
    required String method,
    required WindowActivationRequestedMessage message,
  }) = WindowActivationRequestedEvent;

  /// A window asks for the user's attention (X11 demands-attention or a
  /// Wayland `xdg_activation_v1` request for an existing window). The shell
  /// synthesizes a notification instead of focusing the window.
  const factory PlatformEvent.windowAttentionRequested({
    required String method,
    required WindowAttentionRequestedMessage message,
  }) = WindowAttentionRequestedEvent;

  /// A window no longer asks for the user's attention: the shell drops the
  /// live notification it synthesized.
  const factory PlatformEvent.windowAttentionReleased({
    required String method,
    required WindowAttentionReleasedMessage message,
  }) = WindowAttentionReleasedEvent;

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
