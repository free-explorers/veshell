import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/provider/monitor_list.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/screen_list.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/wayland/model/event/destroy_surface/destroy_surface.serializable.dart';
import 'package:shell/wayland/model/event/wayland_event.serializable.dart';
import 'package:shell/wayland/model/request/close_window/close_window.serializable.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/model/xdg_surface.dart';
import 'package:shell/wayland/provider/surface.manager.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';
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
    ref
      ..listen(
        newXdgToplevelSurfaceProvider,
        (_, next) async {
          if (next case AsyncData(value: final SurfaceId surfaceId)) {
            onNewToplevel(surfaceId);
          }
        },
      )
      ..listen(waylandManagerProvider, (_, next) {
        if (next case AsyncData(value: final DestroySurfaceEvent event)) {
          _onSurfaceIsDestroyed(event.message);
        }
      });
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

  /// new toplevel handler
  ///
  /// This is called when a new toplevel surface is created
  /// it first search for a waiting persistent window
  void onNewToplevel(SurfaceId surfaceId) {
    final toplevelState = ref.read(xdgToplevelStateProvider(surfaceId));

    for (final windowId in state) {
      final window = ref.read(windowStateProvider(windowId));
      if (window is PersistentWindow) {
        if (window.appId == toplevelState.appId && window.isWaitingForSurface) {
          ref.read(windowStateProvider(windowId).notifier).initialize(
                window.copyWith(
                  title: toplevelState.title,
                  surfaceId: surfaceId,
                  isWaitingForSurface: false,
                ),
              );
          return;
        }
      }
    }
    if (toplevelState.parentSurfaceId != null) {
      _createDialogWindowForSurface(toplevelState);
      return;
    }
    // create a new window
    _createPersistentWindowForSurface(toplevelState);
  }

  _createPersistentWindowForSurface(XdgToplevelSurface toplevelState) {
    // create a new window
    final windowId = _uuidGenerator.v4();

    final persistentWindow = PersistentWindow(
      windowId: windowId,
      appId: toplevelState.appId,
      title: toplevelState.title,
      surfaceId: toplevelState.surfaceId,
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

  _createDialogWindowForSurface(XdgToplevelSurface toplevelState) {
    // create a new window
    final windowId = _uuidGenerator.v4();

    final dialogWindow = DialogWindow(
      windowId: windowId,
      appId: toplevelState.appId,
      title: toplevelState.title,
      surfaceId: toplevelState.surfaceId,
      parentSurfaceId: toplevelState.parentSurfaceId!,
    );

    ref.read(windowStateProvider(windowId).notifier).initialize(dialogWindow);

    state = state.add(windowId);

    final parentWindowId =
        ref.read(surfaceWindowMapProvider).get(toplevelState.parentSurfaceId!)!;

    ref.read(dialogListForWindowProvider.notifier).add(
          parentWindowId,
          windowId,
        );
  }

  _onSurfaceIsDestroyed(DestroySurfaceMessage message) {
    if (ref.read(surfaceWindowMapProvider).get(message.surfaceId)
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

  closeWindow(WindowId windowId) {
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
