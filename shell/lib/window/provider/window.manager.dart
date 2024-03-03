import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/provider/monitor_list.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/screen_list.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/wayland/model/request/close_window/close_window.serializable.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/model/xdg_toplevel.dart';
import 'package:shell/wayland/provider/surface.manager.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/provider/xdg_toplevel_state.dart';
import 'package:shell/window/model/window.dart';
import 'package:shell/window/provider/dialog_list_for_window.dart';
import 'package:shell/window/provider/surface_window_map.dart';
import 'package:shell/window/provider/window_state.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:uuid/uuid.dart';

part 'window.manager.g.dart';

/// Typedef for WindowId
typedef WindowId = String;

/// Window manager
@Riverpod(keepAlive: true)
class WindowManager extends _$WindowManager {
  final _uuidGenerator = const Uuid();

  @override
  ISet<WindowId> build() {
    ref.listen(
      surfaceMappedProvider,
      (_, next) async {
        switch (next) {
          case AsyncData(value: final SurfaceMappedEvent event):
            _onSurfaceMapped(event.surfaceId);
          case AsyncData(value: final SurfaceUnmappedEvent event):
            _onSurfaceUnmapped(event.surfaceId);
        }
      },
    );
    return <WindowId>{}.lock;
  }

  /// Create persistent window for desktop entry
  WindowId createPersistentWindowForDesktopEntry(
    LocalizedDesktopEntry entry,
  ) {
    final windowId = _uuidGenerator.v4();

    final persistentWindow = PersistentWindow(
      windowId: windowId,
      appId: entry.desktopEntry.id ?? '',
      title: entry.desktopEntry.id ?? '',
      isWaitingForSurface: true,
    );

    ref
        .read(windowStateProvider(windowId).notifier)
        .initialize(persistentWindow);

    state = state.add(windowId);
    return windowId;
  }

  /// Surface mapped handler
  ///
  /// This is called when a toplevel or X11 surface is mapped.
  /// It searches for a waiting persistent window.
  void _onSurfaceMapped(SurfaceId surfaceId) {
    final role = ref.read(wlSurfaceStateProvider(surfaceId)).role;

    if (role case SurfaceRole.xdgToplevel) {
      _onToplevelMapped(surfaceId);
    } else if (role case SurfaceRole.x11Surface) {
      _onX11SurfaceMapped(surfaceId);
    }
  }

  void _onToplevelMapped(SurfaceId surfaceId) {
    final toplevelState = ref.read(xdgToplevelStateProvider(surfaceId));

    for (final windowId in state) {
      final window = ref.read(windowStateProvider(windowId));
      if (window is PersistentWindow) {
        if (window.appId == toplevelState.appId && window.isWaitingForSurface) {
          ref.read(windowStateProvider(windowId).notifier).initialize(
                window.copyWith(
                  title: toplevelState.title ?? window.title,
                  surfaceId: surfaceId,
                  isWaitingForSurface: false,
                ),
              );
          return;
        }
      }
    }
    if (toplevelState.parent != null) {
      _createDialogWindowForSurface(surfaceId, toplevelState);
      return;
    }
    // create a new window
    _createPersistentWindowForSurface(
      surfaceId: surfaceId,
      appId: toplevelState.appId,
      title: toplevelState.title,
    );
  }

  void _onX11SurfaceMapped(SurfaceId surfaceId) {
    for (final windowId in state) {
      final window = ref.read(windowStateProvider(windowId));
      if (window is PersistentWindow) {
        if (window.isWaitingForSurface) {
          ref.read(windowStateProvider(windowId).notifier).initialize(
                window.copyWith(
                  title: window.title,
                  surfaceId: surfaceId,
                  isWaitingForSurface: false,
                ),
              );
          return;
        }
      }
    }

    // create a new window
    _createPersistentWindowForSurface(
      surfaceId: surfaceId,
      // TODO(roscale): Get X11 surface information from Smithay.
      appId: null,
      title: null,
    );
  }

  void _createPersistentWindowForSurface({
    required SurfaceId surfaceId,
    required String? appId,
    required String? title,
  }) {
    // create a new window
    final windowId = _uuidGenerator.v4();

    final persistentWindow = PersistentWindow(
      windowId: windowId,
      appId: appId ?? 'unknown',
      title: title ?? 'unknown',
      surfaceId: surfaceId,
    );

    ref
        .read(windowStateProvider(windowId).notifier)
        .initialize(persistentWindow);

    state = state.add(windowId);
    final monitorName = ref.read(monitorListProvider).first.name;
    final screenList = ref.read(screenListProvider(monitorName));
    final currentScreenId = ref.read(focusedScreenProvider) ?? screenList.first;
    final screenState = ref.read(screenStateProvider(currentScreenId));

    ref
        .read(
          workspaceStateProvider(
            screenState.workspaceList[screenState.selectedIndex],
          ).notifier,
        )
        .addWindow(windowId);
  }

  void _createDialogWindowForSurface(
    SurfaceId surfaceId,
    XdgToplevel toplevelState,
  ) {
    // create a new window
    final windowId = _uuidGenerator.v4();

    final dialogWindow = DialogWindow(
      windowId: windowId,
      appId: toplevelState.appId ?? 'unknown',
      title: toplevelState.title ?? 'unknown',
      surfaceId: surfaceId,
      parentSurfaceId: toplevelState.parent!,
    );

    ref.read(windowStateProvider(windowId).notifier).initialize(dialogWindow);

    state = state.add(windowId);

    final parentWindowId =
        ref.read(surfaceWindowMapProvider).get(toplevelState.parent!)!;

    ref.read(dialogListForWindowProvider.notifier).add(
          parentWindowId,
          windowId,
        );
  }

  void _onSurfaceUnmapped(SurfaceId surfaceId) {
    if (ref.read(surfaceWindowMapProvider).get(surfaceId)
        case final WindowId windowId) {
      ref.read(windowStateProvider(windowId).notifier).onSurfaceIsDestroyed();

      final windowState = ref.read(windowStateProvider(windowId));
      if (windowState case final DialogWindow dialogWindow) {
        ref.read(dialogListForWindowProvider.notifier).remove(
              ref
                  .read(surfaceWindowMapProvider)
                  .get(dialogWindow.parentSurfaceId)!,
              dialogWindow.windowId,
            );
        state = state.remove(windowId);
      }
    }
  }

  void closeWindow(WindowId windowId) {
    final windowState = ref.read(windowStateProvider(windowId));

    ref.read(waylandManagerProvider.notifier).request(
          CloseWindowRequest(
            message: CloseWindowMessage(
              surfaceId: windowState.surfaceId!,
            ),
          ),
        );
  }
}
