import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/display/monitor/screen/screen.provider.dart';
import 'package:shell/display/monitor/screen/workspace/workspace.provider.dart';
import 'package:shell/manager/wayland/event/destroy_surface/destroy_surface.model.serializable.dart';
import 'package:shell/manager/wayland/event/wayland_event.model.serializable.dart';
import 'package:shell/manager/wayland/surface/surface.manager.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';
import 'package:shell/manager/wayland/surface/xdg_surface/xdg_surface.model.dart';
import 'package:shell/manager/wayland/surface/xdg_surface/xdg_toplevel.provider.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';
import 'package:shell/manager/window/window.model.dart';
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

    final currentScreenId = ref.read(focusedScreenProvider);
    final screenState = ref.read(screenStateProvider(currentScreenId!));

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
}

/// Workspace provider
@riverpod
class WindowState extends _$WindowState {
  ProviderSubscription<XdgToplevelSurface>? _surfaceSubscription;
  KeepAliveLink? _keepAliveLink;

  @override
  Window build(WindowId windowId) {
    throw Exception('WindowState $windowId not yet initialized');
  }

  void initialize(Window window) {
    _keepAliveLink?.close();
    _keepAliveLink = ref.keepAlive();

    state = window;
    if (state.surfaceId != null) {
      ref.read(surfaceWindowMapProvider.notifier).add(
            state.surfaceId!,
            state.windowId,
          );
      _listenForSurfaceChanges();
    }
  }

  void _listenForSurfaceChanges() {
    if (state.surfaceId == null) {
      return;
    }
    if (_surfaceSubscription != null) {
      _surfaceSubscription?.close();
    }
    _surfaceSubscription =
        ref.listen(xdgToplevelStateProvider(state.surfaceId!), (_, next) {
      state = state.copyWith(appId: next.appId, title: next.title);
    });
  }

  void onSurfaceIsDestroyed() {
    _surfaceSubscription?.close();
    ref.read(surfaceWindowMapProvider.notifier).remove(state.surfaceId!);
    if (state case final PersistentWindow persistentWindow) {
      state = persistentWindow.copyWith(surfaceId: null);
    } else {
      _keepAliveLink?.close();
    }
  }

  void update(Window window) {
    state = window;
  }
}

@Riverpod(keepAlive: true)
class SurfaceWindowMap extends _$SurfaceWindowMap {
  @override
  IMap<SurfaceId, WindowId> build() {
    return IMap();
  }

  void add(SurfaceId surfaceId, WindowId windowId) {
    state = state.add(surfaceId, windowId);
  }

  void remove(SurfaceId surfaceId) {
    state = state.remove(surfaceId);
  }
}

@Riverpod(keepAlive: true)
class DialogListForWindow extends _$DialogListForWindow {
  @override
  IMapOfSets<WindowId, WindowId> build() {
    return IMapOfSets();
  }

  void add(WindowId parentWindowId, WindowId windowId) {
    state = state.add(parentWindowId, windowId);
  }

  void remove(WindowId parentWindowId, WindowId windowId) {
    state = state.remove(parentWindowId, windowId);
  }
}
