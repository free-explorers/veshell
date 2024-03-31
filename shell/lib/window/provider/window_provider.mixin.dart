import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/model/window_properties.dart';
import 'package:shell/window/provider/surface_window_map.dart';
import 'package:shell/window/provider/window_properties.dart';

mixin WindowProviderMixin<T extends Window> on BuildlessAutoDisposeNotifier<T> {
  ProviderSubscription<WindowPropertiesState>? _surfaceSubscription;
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
        ref.listen(windowPropertiesProvider(state.surfaceId!), (_, next) {
      onSurfaceChanged(next);
    });
  }

  void onSurfaceChanged(WindowPropertiesState windowProperties);

  void onSurfaceIsDestroyed() {
    _surfaceSubscription?.close();
    ref.read(surfaceWindowMapProvider.notifier).remove(state.surfaceId!);
  }

  void dispose() {
    _keepAliveLink?.close();
  }
}
