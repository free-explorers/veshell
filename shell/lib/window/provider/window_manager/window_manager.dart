import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/shared/provider/persistent_json_by_folder.dart';
import 'package:shell/wayland/model/request/close_window/close_window.serializable.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/model/xdg_toplevel.dart';
import 'package:shell/wayland/provider/surface.manager.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/provider/x11_surface_state.dart';
import 'package:shell/wayland/provider/xdg_toplevel_state.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/dialog_list_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/surface_window_map.dart';
import 'package:shell/window/provider/window_manager/matching_engine.dart';
import 'package:shell/workspace/provider/window_workspace_map.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:uuid/uuid.dart';

part 'window_manager.g.dart';

/// Window manager
@Riverpod(keepAlive: true)
class WindowManager extends _$WindowManager {
  final _uuidGenerator = const Uuid();

  ISet<PersistentWindowId> get _persistentWindowSet =>
      state.whereType<PersistentWindowId>().toISet();

  @override
  ISet<WindowId> build() {
    print('WindowManager build');
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

    final intialSet = ref
            .read(persistentJsonByFolderProvider)
            .requireValue['Window']
            ?.keys
            .map<WindowId>(
              PersistentWindowId.new,
            )
            .toISet() ??
        <WindowId>{}.lock;

    return intialSet;
  }

  /// Get the Persistent Window Set
  ISet<PersistentWindowId> getPersistentWindowSet() => _persistentWindowSet;

  /// Create persistent window for desktop entry
  PersistentWindowId createPersistentWindowForDesktopEntry(
    LocalizedDesktopEntry entry,
  ) {
    final windowId = PersistentWindowId(_uuidGenerator.v4());

    final persistentWindow = PersistentWindow(
      windowId: windowId,
      properties: WindowProperties(
        appId: entry.desktopEntry.id ?? '',
        title: entry.entries[DesktopEntryKey.name.string],
      ),
    );

    ref
        .read(persistentWindowStateProvider(windowId).notifier)
        .initialize(persistentWindow);

    state = state.add(windowId);
    return windowId;
  }

  /// Surface mapped handler
  ///
  /// This is called when a toplevel or X11 surface is mapped.
  /// It searches for a waiting persistent window.
  void _onSurfaceMapped(SurfaceId surfaceId) {
    print('WindowManager: Surface mapped: $surfaceId');
    final role = ref.read(wlSurfaceStateProvider(surfaceId)).role;

    if (role case SurfaceRole.xdgToplevel) {
      _onToplevelMapped(surfaceId);
    } else if (role case SurfaceRole.x11Surface) {
      _onX11SurfaceMapped(surfaceId);
    }
  }

  void _onToplevelMapped(SurfaceId surfaceId) {
    final toplevelState = ref.read(xdgToplevelStateProvider(surfaceId));

    if (toplevelState.parent != null) {
      _createDialogWindowForSurface(surfaceId, toplevelState);
      return;
    }

    ref.read(matchingEngineProvider.notifier).addSurface(surfaceId);
  }

  void _onX11SurfaceMapped(SurfaceId surfaceId) {
    final x11SurfaceId = ref.read(x11SurfaceIdByWlSurfaceIdProvider(surfaceId));
    final x11SurfaceState = ref.read(x11SurfaceStateProvider(x11SurfaceId));

    if (x11SurfaceState.overrideRedirect) {
      // Override redirect surfaces should not be managed by the window manager.
      return;
    }
    ref.read(matchingEngineProvider.notifier).addSurface(surfaceId);
  }

  void createPersistentWindowForSurface({
    required SurfaceId surfaceId,
    required String? appId,
    required String? title,
  }) {
    // create a new window
    final windowId = PersistentWindowId(_uuidGenerator.v4());

    final persistentWindow = PersistentWindow(
      windowId: windowId,
      properties: WindowProperties(
        appId: appId ?? '',
        title: title,
      ),
      surfaceId: surfaceId,
    );

    ref
        .read(persistentWindowStateProvider(windowId).notifier)
        .initialize(persistentWindow);

    state = state.add(windowId);

    final currentScreenId = ref.read(focusedScreenProvider);
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
    final windowId = DialogWindowId(_uuidGenerator.v4());

    final dialogWindow = DialogWindow(
      windowId: windowId,
      properties: WindowProperties(
        appId: toplevelState.appId ?? 'unknown',
        title: toplevelState.title ?? 'unknown',
      ),
      surfaceId: surfaceId,
      parentSurfaceId: toplevelState.parent!,
    );

    ref
        .read(dialogWindowStateProvider(windowId).notifier)
        .initialize(dialogWindow);

    state = state.add(windowId);
    final parentWindowId =
        ref.read(surfaceWindowMapProvider).get(toplevelState.parent!)!;

    ref.read(dialogListForWindowProvider.notifier).add(
          parentWindowId,
          windowId,
        );
  }

  void _onSurfaceUnmapped(SurfaceId surfaceId) {
    print('WindowManager: Surface UnMapped: $surfaceId');
    if (ref.read(surfaceWindowMapProvider).get(surfaceId)
        case final WindowId windowId) {
      switch (windowId) {
        case PersistentWindowId():
          ref
              .read(persistentWindowStateProvider(windowId).notifier)
              .onSurfaceIsDestroyed();
          ref.read(matchingEngineProvider.notifier).removeSurface(surfaceId);
        case DialogWindowId():
          final dialogWindow = ref.read(dialogWindowStateProvider(windowId));

          ref.read(dialogListForWindowProvider.notifier).remove(
                ref
                    .read(surfaceWindowMapProvider)
                    .get(dialogWindow.parentSurfaceId)!,
                dialogWindow.windowId,
              );
          ref
              .read(dialogWindowStateProvider(windowId).notifier)
              .onSurfaceIsDestroyed();
          _removeWindow(windowId);
        case EphemeralWindowId():
        // TODO: Handle this case.
      }
    }
  }

  void _removeWindow(WindowId windowId) {
    state = state.remove(windowId);
    switch (windowId) {
      case PersistentWindowId():
        ref.read(persistentWindowStateProvider(windowId).notifier).dispose();
      case DialogWindowId():
        ref.read(dialogWindowStateProvider(windowId).notifier).dispose();
      case EphemeralWindowId():
    }
  }

  void closeWindow(WindowId windowId) {
    switch (windowId) {
      case PersistentWindowId():
        final persistentWindow =
            ref.read(persistentWindowStateProvider(windowId));
        if (persistentWindow.surfaceId != null) {
          closeWindowSurface(persistentWindow.surfaceId!);
        } else {
          _removeWindow(windowId);
          final workspaceId =
              ref.read(windowWorkspaceMapProvider).get(windowId);
          if (workspaceId != null) {
            ref
                .read(workspaceStateProvider(workspaceId).notifier)
                .removeWindow(windowId);
          }
        }
      case DialogWindowId():
        closeWindowSurface(
          ref.read(dialogWindowStateProvider(windowId)).surfaceId,
        );
      case EphemeralWindowId():
    }
  }

  /// Close surface for window
  void closeWindowSurface(SurfaceId surfaceId) {
    ref.read(waylandManagerProvider.notifier).request(
          CloseWindowRequest(
            message: CloseWindowMessage(
              surfaceId: surfaceId,
            ),
          ),
        );
  }
}
