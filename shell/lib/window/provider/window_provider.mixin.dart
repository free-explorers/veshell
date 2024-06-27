import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/model/launch_config.serializable.dart';
import 'package:shell/application/provider/app_launch.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/surface_window_map.dart';
import 'package:shell/window/provider/window_properties.dart';

mixin WindowProviderMixin<T extends Window> on BuildlessAutoDisposeNotifier<T> {
  ProviderSubscription<WindowProperties>? _surfaceSubscription;
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
      closeSurfaceSubscription();
    }
    _surfaceSubscription =
        ref.listen(windowPropertiesStateProvider(state.surfaceId!), (_, next) {
      onSurfaceChanged(next);
    });
  }

  Future<Process?> launchSelf() async {
    final entry = ref
        .watch(
          localizedDesktopEntryForIdProvider(state.properties.appId),
        )
        .value;

    if (entry == null) {
      return null;
    }
    return ref.read(appLaunchProvider.notifier).launchApplication(
          LaunchConfig.fromDesktopEntry(entry.desktopEntry),
        );
  }

  void onSurfaceChanged(WindowProperties windowProperties);

  void onSurfaceIsDestroyed() {
    closeSurfaceSubscription();
    ref.read(surfaceWindowMapProvider.notifier).remove(state.surfaceId!);
  }

  void closeSurfaceSubscription() {
    _surfaceSubscription?.close();
  }

  void dispose() {
    _keepAliveLink?.close();
  }
}
