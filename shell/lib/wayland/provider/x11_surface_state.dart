import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/model/x11_surface.dart';
import 'package:shell/wayland/provider/surface.manager.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';

part 'x11_surface_state.g.dart';

@riverpod
class X11SurfaceState extends _$X11SurfaceState {
  late final KeepAliveLink _keepAliveLink;

  @override
  X11Surface build(X11SurfaceId x11SurfaceId) {
    throw Exception('X11Surface $x11SurfaceId not yet initialized');
  }

  void initialize() {
    _keepAliveLink = ref.keepAlive();
    ref.onDispose(() {
      print('disposing X11SurfaceStateProvider $x11SurfaceId');
    });

    state = X11Surface(
      x11SurfaceId: x11SurfaceId,
      surfaceId: null,
      mapped: false,
      overrideRedirect: false,
      geometry: Rect.zero,
      parent: null,
      children: IList<X11SurfaceId>(),
      title: '',
      windowClass: '',
      instance: '',
      startupId: null,
    );
  }

  void map({
    required SurfaceId surfaceId,
    required bool overrideRedirect,
    required Rect geometry,
    required X11SurfaceId? parent,
    required String title,
    required String windowClass,
    required String instance,
    required String? startupId,
  }) {
    assert(!state.mapped);

    X11SurfaceId? previousParent = state.parent;

    state = state.copyWith(
      surfaceId: surfaceId,
      mapped: true,
      overrideRedirect: overrideRedirect,
      geometry: geometry,
      parent: parent,
      title: title,
      windowClass: windowClass,
      instance: instance,
      startupId: startupId,
    );

    assert(state.surfaceId != null);

    ref.read(wlSurfaceStateProvider(surfaceId).notifier).setX11SurfaceRole();

    ref
        .read(x11SurfaceIdByWlSurfaceIdProvider(state.surfaceId!).notifier)
        .linkX11Surface(x11SurfaceId);

    if (previousParent != parent) {
      if (parent != null) {
        ref
            .read(x11SurfaceStateProvider(parent).notifier)
            .addChild(x11SurfaceId);
      }
      if (previousParent != null) {
        ref
            .read(x11SurfaceStateProvider(previousParent).notifier)
            .removeChild(x11SurfaceId);
      }
    }

    if (!state.overrideRedirect || state.parent == null) {
      ref.read(surfaceMappedProvider.notifier).mapped(surfaceId);
    }
  }

  void addChild(X11SurfaceId child) {
    state = state.copyWith(
      children: state.children.add(child),
    );
  }

  void removeChild(X11SurfaceId child) {
    state = state.copyWith(
      children: state.children.remove(child),
    );
  }

  void unmap() {
    assert(state.surfaceId != null);
    assert(state.mapped);

    if (!state.overrideRedirect || state.parent == null) {
      ref.read(surfaceMappedProvider.notifier).unmapped(state.surfaceId!);
    }

    if (state.parent != null) {
      ref
          .read(x11SurfaceStateProvider(state.parent!).notifier)
          .removeChild(x11SurfaceId);
    }

    ref
        .read(x11SurfaceIdByWlSurfaceIdProvider(state.surfaceId!).notifier)
        .unlinkX11Surface();

    state = state.copyWith(
      surfaceId: null,
      mapped: false,
    );
  }

  void dispose() {
    if (state.mapped) {
      if (!state.overrideRedirect || state.parent == null) {
        ref.read(surfaceMappedProvider.notifier).unmapped(state.surfaceId!);
      }
      if (state.parent != null) {
        ref
            .read(x11SurfaceStateProvider(state.parent!).notifier)
            .removeChild(x11SurfaceId);
      }
      ref
          .read(x11SurfaceIdByWlSurfaceIdProvider(state.surfaceId!).notifier)
          .unlinkX11Surface();
    }
    _keepAliveLink.close();
  }
}

@riverpod
class X11SurfaceIdByWlSurfaceId extends _$X11SurfaceIdByWlSurfaceId {
  late final KeepAliveLink _keepAliveLink;

  @override
  X11SurfaceId build(SurfaceId surfaceId) {
    throw Exception(
      "Surface $surfaceId hasn't been linked with an X11Surface",
    );
  }

  void linkX11Surface(X11SurfaceId x11SurfaceId) {
    _keepAliveLink = ref.keepAlive();
    ref.onDispose(() {
      print('disposing X11SurfaceIdByWlSurfaceId $x11SurfaceId');
    });

    state = x11SurfaceId;
  }

  void unlinkX11Surface() {
    _keepAliveLink.close();
  }
}
