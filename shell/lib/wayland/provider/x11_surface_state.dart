import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/model/x11_surface.dart';
import 'package:shell/wayland/provider/surface.manager.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/window_properties.dart';

part 'x11_surface_state.g.dart';

@riverpod
class X11SurfaceState extends _$X11SurfaceState {
  late final KeepAliveLink _keepAliveLink;

  ProviderSubscription<SurfaceTexture?>? textureSubscription;

  @override
  X11Surface build(X11SurfaceId x11SurfaceId) {
    throw Exception('X11Surface $x11SurfaceId not yet initialized');
  }

  void initialize({required bool overrideRedirect}) {
    _keepAliveLink = ref.keepAlive();
    ref.onDispose(() {
      print('disposing X11SurfaceStateProvider $x11SurfaceId');
    });

    state = X11Surface(
      x11SurfaceId: x11SurfaceId,
      surfaceId: null,
      mapped: false,
      overrideRedirect: overrideRedirect,
      geometry: Rect.zero,
      parent: null,
      children: IList<X11SurfaceId>(),
      title: null,
      windowClass: null,
      instance: null,
      startupId: null,
    );
  }

  void map({required Rect geometry, int? parent}) {
    final previousParent = state.parent;
    state = state.copyWith(parent: parent, geometry: geometry);
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
/*     assert(state.surfaceId == null);

   

    state = state.copyWith(
      surfaceId: surfaceId,
      overrideRedirect: overrideRedirect,
      geometry: geometry,
      parent: parent,
      title: title,
      windowClass: windowClass,
      instance: instance,
      startupId: startupId,
    );

    assert(state.surfaceId != null);

    

    
*/

    _checkIfMapped();
  }

  void unmap() {
    assert(state.surfaceId != null);

    if (state.mapped && state.parent == null) {
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
      parent: null,
    );
  }

  void associate(SurfaceId surfaceId) {
    state = state.copyWith(surfaceId: surfaceId);
    ref
        .read(x11SurfaceIdByWlSurfaceIdProvider(surfaceId).notifier)
        .linkX11Surface(x11SurfaceId);
    if (textureSubscription != null) textureSubscription!.close();
    textureSubscription = ref.listen(
      wlSurfaceStateProvider(surfaceId).select((value) => value.texture),
      (_, __) => _checkIfMapped(),
    );
    ref
        .read(windowPropertiesStateProvider(state.surfaceId!).notifier)
        .setProperties(
          WindowProperties(
            appId: state.instance ?? '',
            title: state.title,
            windowClass: state.windowClass,
            startupId: state.startupId,
          ),
        );
    _checkIfMapped();
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

  void setTitle(String title) {
    state = state.copyWith(title: title);
  }

  void setAppId(String appId) {
    state = state.copyWith(instance: appId);
  }

  void setStartupId(String startupId) {
    state = state.copyWith(startupId: startupId);
  }

  void setGeometry(Rect geometry) {
    state = state.copyWith(geometry: geometry);
  }

  void setOverrideRedirect(bool overrideRedirect) {
    state = state.copyWith(overrideRedirect: overrideRedirect);
  }

  void setProperties({
    required String? title,
    required String? windowClass,
    required String? instance,
    required String? startupId,
  }) {
    state = state.copyWith(
      title: title,
      windowClass: windowClass,
      instance: instance,
      startupId: startupId,
    );
    if (state.surfaceId != null) {
      ref
          .read(windowPropertiesStateProvider(state.surfaceId!).notifier)
          .setProperties(
            WindowProperties(
              appId: instance ?? '',
              title: title,
              windowClass: windowClass,
              startupId: startupId,
            ),
          );
    }
  }

  void _checkIfMapped() {
    final wasMapped = state.mapped;
    bool mapped;

    final surfaceId = state.surfaceId;
    if (surfaceId != null) {
      final texture = ref.read(wlSurfaceStateProvider(surfaceId)).texture;
      mapped = texture != null;
    } else {
      mapped = false;
    }

    if (state.parent == null) {
      if (wasMapped && !mapped) {
        ref.read(surfaceMappedProvider.notifier).unmapped(state.surfaceId!);
      } else if (!wasMapped && mapped) {
        ref.read(surfaceMappedProvider.notifier).mapped(state.surfaceId!);
      }
    }

    state = state.copyWith(mapped: mapped);
  }

  void dispose() {
    textureSubscription?.close();

    if (state.mapped) {
      if (state.parent == null) {
        ref.read(surfaceMappedProvider.notifier).unmapped(state.surfaceId!);
      } else {
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
