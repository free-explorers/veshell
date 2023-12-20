import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/manager/wayland/surface/surface.manager.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';
import 'package:shell/manager/wayland/surface/xdg_surface/xdg_popup.provider.dart';
import 'package:shell/manager/wayland/surface/xdg_surface/xdg_toplevel.provider.dart';
import 'package:shell/manager/window/window.model.dart';
import 'package:uuid/uuid.dart';

part 'window.manager.g.dart';

/// Typedef for WindowId
typedef WindowId = String;

/// Window manager
@Riverpod(keepAlive: true)
class WindowManager extends _$WindowManager {
  final _uuidGenerator = const Uuid();
  final IMap<SurfaceId, WindowId> _surfaceWindowMap = IMap();

  @override
  IMap<WindowId, Window> build() {
    ref
      ..listen(
        newXdgToplevelSurfaceProvider,
        (_, next) async {
          if (next case AsyncData(value: final SurfaceId surfaceId)) {
            onNewToplevel(surfaceId);
          }
        },
      )
      ..listen(
        newXdgPopupSurfaceProvider,
        (_, next) async {
          if (next case AsyncData(value: final SurfaceId surfaceId)) {
            onNewPopup(surfaceId);
          }
        },
      );
    return <WindowId, Window>{}.lock;
  }

  /// Create persistent window for desktop entry
  WindowId createPersistentWindowForDesktopEntry(
    LocalizedDesktopEntry entry,
  ) {
    final persistentWindow = PersistentWindow(
      appId: entry.desktopEntry.id ?? '',
      title: '',
      isWaitingForSurface: true,
    );
    final windowId = _uuidGenerator.v4();
    state = state.add(windowId, persistentWindow);
    return windowId;
  }

  /// new toplevel handler
  ///
  /// This is called when a new toplevel surface is created
  /// it first search for a waiting persistent window
  onNewToplevel(SurfaceId surfaceId) {
    final toplevelState = ref.read(xdgToplevelStateProvider(surfaceId));

    for (final entry in state.toEntryIList()) {
      if (entry case MapEntry(value: final PersistentWindow window)) {
        if (window.appId == toplevelState.appId && window.isWaitingForSurface) {
          state = state.update(
            entry.key,
            (value) => window.copyWith(
              title: toplevelState.title,
              surfaceId: surfaceId,
              isWaitingForSurface: false,
            ),
          );
        }
      }
    }
  }

  onNewPopup(SurfaceId surfaceId) {
    final popupState = ref.read(xdgPopupStateProvider(surfaceId));
  }
}

/// Workspace provider
@riverpod
class WindowState extends _$WindowState {
  late WindowId _windowId;
  @override
  Window build(WindowId windowId) {
    final window =
        ref.watch(windowManagerProvider.select((value) => value.get(windowId)));
    if (window == null) {
      throw Exception('Window $windowId not found');
    }
    _windowId = windowId;
    return window;
  }
}

/* @riverpod
void surfaceCommitHandler(SurfaceCommitHandlerRef ref) {
  ref.listen(waylandManagerProvider, (_, next) {
    if (next case AsyncData(value: final DestroySurfaceEvent event)) {
      // do something when this event occurs
    }
  });

  return;
} */

/* @riverpod
Future<DestroySurfaceEvent> destroySurfaceEvents(DestroySurfaceEventRef ref) {
  ref.listen(
    waylandManagerProvider,
    (_, next) {
      if (next case AsyncData(value: final DestroySurfaceEvent event)) {
        ref.state = AsyncData(event);
      }
    },
    fireImmediately: true,
  );
  // stay in loading until that^ trigers
  return ref.future;
} */
