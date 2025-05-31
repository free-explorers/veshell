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

part 'meta_window_state.g.dart';

@riverpod
class MetaWindowState extends _$MetaWindowState {
  KeepAliveLink? _keepAliveLink;

  @override
  MetaWindow build(String id) {
    throw Exception('MetaWindowState $id not yet initialized');
  }

  Future<void> create(MetaWindowCreatedMessage message) async {
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
      mapped: message.mapped,
      title: message.title,
      windowClass: message.windowClass,
      startupId: message.startupId,
      geometry: message.geometry,
      needDecoration: message.needDecoration,
      gameModeActivated: message.gameModeActivated,
    );

    ref
        .read(
          metaWindowIdPerSurfaceIdProvider(message.surfaceId).notifier,
        )
        .set(id);

    ref.watch(pidToMetaWindowIdProvider(message.pid).notifier).set(id);
  }

  Future<void> patch(
    MetaWindowPatchMessage patch, {
    bool propagate = true,
  }) async {
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
      case UpdateTitle():
        state = state.copyWith(title: patch.value);
      case UpdatePid():
        state = state.copyWith(pid: patch.value);
      case UpdateWindowClass():
        state = state.copyWith(windowClass: patch.value);
      case UpdateStartupId():
        state = state.copyWith(startupId: patch.value);
      case UpdateDisplayMode():
        state = state.copyWith(displayMode: patch.value);
      case UpdateMapped():
        state = state.copyWith(mapped: patch.value);
      case UpdateGeometry():
        state = state.copyWith(geometry: patch.value);
      case UpdateNeedDecoration():
        state = state.copyWith(needDecoration: patch.value);
      case UpdateGameModeActivated():
        state = state.copyWith(gameModeActivated: patch.value);
    }
    if (propagate == true) {
      await ref.read(platformManagerProvider.notifier).request(
            MetaWindowPatchesRequest(
              message: patch,
            ),
          );
    }
  }

  void destroy() {
    _keepAliveLink?.close();
    ref
        .read(
          metaWindowIdPerSurfaceIdProvider(state.surfaceId).notifier,
        )
        .clear();
  }

  void requestToClose() {
    ref.read(platformManagerProvider.notifier).request(
          CloseWindowRequest(
            message: CloseWindowMessage(
              metaWindowId: state.id,
            ),
          ),
        );
  }
}
