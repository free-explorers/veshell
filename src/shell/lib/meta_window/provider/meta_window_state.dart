import 'dart:ui';

import 'package:hooks_riverpod/misc.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_id_per_surface_id.dart';
import 'package:shell/meta_window/provider/pid_to_meta_window_id.dart';
import 'package:shell/platform/model/event/meta_window_created/meta_window_created.serializable.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/platform/model/request/close_window/close_window.serializable.dart';
import 'package:shell/platform/model/request/meta_window_patches/meta_window_patches.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/util/logger.dart';

part 'meta_window_state.g.dart';

@riverpod
class MetaWindowState extends _$MetaWindowState {
  KeepAliveLink? _keepAliveLink;

  // `build()` throws until [create] runs; trackers such as
  // [MetaWindowManager] mount this provider only after a creation event, and
  // these guards keep a teardown or patch event racing past that mount from
  // crashing on the uninitialized provider.
  bool _created = false;

  /// Whether the shell asked the client to close this window (title-bar close,
  /// tile close or the close hotkey). Runtime-only: it lets the owning tile
  /// tell a closure it requested from one the application performed itself,
  /// such as a password safe replacing its unlock window with its main window.
  bool _closeRequested = false;

  /// Whether the shell requested the closure of this window.
  bool get closeRequested => _closeRequested;

  @override
  MetaWindow build(String id) {
    throw Exception('MetaWindowState $id not yet initialized');
  }

  Future<void> create(MetaWindowCreatedMessage message) async {
    _created = true;
    geometryLog.info(
      'window create id=$id surface=${message.surfaceId} '
      'geometry=${message.geometry} scale=${message.scaleRatio} '
      'mapped=${message.mapped} parent=${message.parent}',
    );
    _keepAliveLink?.close();
    _keepAliveLink = ref.keepAlive();

    // retrieve the desktop file from the app id
    final desktopEntryForSurface = await ref.read(
      localizedDesktopEntryForIdProvider(message.appId ?? '').future,
    );

    state = MetaWindow(
      id: id,
      pid: message.pid,
      // A MetaWindow can have as appId a desktop file or binary name
      // use the desktop file id if available
      appId: desktopEntryForSurface?.desktopEntry.id ?? message.appId,
      surfaceId: message.surfaceId,
      parent: message.parent,
      activatedBy: message.activatedBy,
      mapped: message.mapped,
      title: message.title,
      windowClass: message.windowClass,
      startupId: message.startupId,
      isFixedSized: message.isFixedSized,
      isModal: message.isModal,
      isFullscreen: message.isFullscreen,
      clientMaximized: message.clientMaximized,
      skipTaskbar: message.skipTaskbar,
      keepOnTop: message.keepOnTop,
      position: message.position,
      positionExplicit: message.positionExplicit,
      viewport: message.viewport,
      geometry: message.geometry,
      needDecoration: message.needDecoration,
      gameModeActivated: message.gameModeActivated,
      scaleRatio: message.scaleRatio,
    );

    ref
        .read(metaWindowIdPerSurfaceIdProvider(message.surfaceId).notifier)
        .set(id);

    ref.watch(pidToMetaWindowIdProvider(message.pid).notifier).set(id);
  }

  Future<void> patch(
    MetaWindowPatchMessage patch, {
    bool propagate = true,
  }) async {
    if (!_created) {
      geometryLog.warning('window patch $patch dropped for id=$id not created');
      return;
    }
    if (patch is UpdateGeometry || patch is UpdateScaleRatio) {
      geometryLog.info('window patch id=$id value=$patch before=${state}');
    }
    switch (patch) {
      case UpdateAppId():
        {
          // retrieve the desktop file from the app id
          final desktopEntryForSurface = await ref.read(
            localizedDesktopEntryForIdProvider(patch.value ?? '').future,
          );

          state = state.copyWith(
            appId: desktopEntryForSurface?.desktopEntry.id ?? patch.value,
          );
        }
      case UpdateParent():
        state = state.copyWith(parent: patch.value);
      case UpdateActivatedBy():
        state = state.copyWith(activatedBy: patch.value);
      case UpdateTitle():
        state = state.copyWith(title: patch.value);
      case UpdatePid():
        state = state.copyWith(pid: patch.value);
      case UpdateWindowClass():
        state = state.copyWith(windowClass: patch.value);
      case UpdateStartupId():
        state = state.copyWith(startupId: patch.value);
      case UpdateIsFixedSized():
        state = state.copyWith(isFixedSized: patch.value);
      case UpdateIsModal():
        state = state.copyWith(isModal: patch.value);
      case UpdateIsFullscreen():
        state = state.copyWith(isFullscreen: patch.value);
      case UpdateClientMaximized():
        state = state.copyWith(clientMaximized: patch.value);
      case UpdateSkipTaskbar():
        state = state.copyWith(skipTaskbar: patch.value);
      case UpdateKeepOnTop():
        state = state.copyWith(keepOnTop: patch.value);
      case UpdateDisplayMode():
        state = state.copyWith(displayMode: patch.value);
      case UpdateViewport():
        state = state.copyWith(viewport: patch.value);
      case UpdateMapped():
        state = state.copyWith(mapped: patch.value);
      case UpdatePosition():
        state = state.copyWith(position: patch.value);
      case UpdatePositionExplicit():
        state = state.copyWith(positionExplicit: patch.value);
      case UpdateRenderOrigin():
        state = state.copyWith(renderOrigin: patch.value);
      case UpdateTileOrigin():
        state = state.copyWith(tileOrigin: patch.value);
      case UpdateGeometry():
        state = state.copyWith(geometry: patch.value);
      case SetWindowRect():
        final rect = patch.value;
        state = state.copyWith(
          position: rect?.topLeft,
          positionExplicit: true,
          geometry: rect == null
              ? null
              // Preserve the CSD visible-content offset inside the surface
              // buffer. Rust keeps it too; resetting it here shifts a Wayland
              // client by its shadow margin on every resize frame.
              : Rect.fromLTWH(
                  state.geometry?.left ?? 0,
                  state.geometry?.top ?? 0,
                  rect.width,
                  rect.height,
                ),
        );
      case UpdateNeedDecoration():
        state = state.copyWith(needDecoration: patch.value);
      case UpdateGameModeActivated():
        state = state.copyWith(gameModeActivated: patch.value);
      case UpdateIsRecording():
        state = state.copyWith(isRecording: patch.value);
      case UpdateCurrentOutput():
        state = state.copyWith(currentOutput: patch.value);
      case UpdateScaleRatio():
        state = state.copyWith(scaleRatio: patch.value);
    }
    if (propagate == true) {
      await ref
          .read(platformManagerProvider.notifier)
          .request(MetaWindowPatchesRequest(message: patch));
    }
  }

  void destroy() {
    _keepAliveLink?.close();
    if (!_created) {
      return;
    }
    _created = false;
    ref
        .read(metaWindowIdPerSurfaceIdProvider(state.surfaceId).notifier)
        .clear();
  }

  void requestToClose() {
    if (!_created) {
      return;
    }
    _closeRequested = true;
    ref
        .read(platformManagerProvider.notifier)
        .request(
          CloseWindowRequest(
            message: CloseWindowMessage(metaWindowId: state.id),
          ),
        );
  }
}
