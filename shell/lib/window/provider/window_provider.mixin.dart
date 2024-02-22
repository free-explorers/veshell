import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/xdg_surface.dart';
import 'package:shell/wayland/provider/xdg_toplevel_state.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/provider/surface_window_map.dart';

mixin WindowProviderMixin<T extends Window> on BuildlessAutoDisposeNotifier<T> {
  ProviderSubscription<XdgToplevelSurface>? _surfaceSubscription;
  KeepAliveLink? _keepAliveLink;

  syncWithSurface() {
    _keepAliveLink?.close();
    _keepAliveLink = ref.keepAlive();
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
      onSurfaceChanged(next);
    });
  }

  void onSurfaceChanged(XdgToplevelSurface surface);

  void onSurfaceIsDestroyed() {
    _surfaceSubscription?.close();
    ref.read(surfaceWindowMapProvider.notifier).remove(state.surfaceId!);
  }

  void dispose() {
    _keepAliveLink?.close();
  }
}
