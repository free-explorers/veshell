import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/xdg_surface.dart';
import 'package:shell/wayland/provider/xdg_toplevel_state.dart';
import 'package:shell/window/model/window.dart';
import 'package:shell/window/provider/surface_window_map.dart';
import 'package:shell/window/provider/window.manager.dart';

part 'window_state.g.dart';

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
