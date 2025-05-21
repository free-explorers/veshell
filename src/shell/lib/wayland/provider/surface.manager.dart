import 'dart:async';
import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/event/commit_surface/commit_surface.serializable.dart';
import 'package:shell/wayland/model/event/destroy_subsurface/destroy_subsurface.serializable.dart';
import 'package:shell/wayland/model/event/destroy_surface/destroy_surface.serializable.dart';
import 'package:shell/wayland/model/event/new_subsurface/new_subsurface.serializable.dart';
import 'package:shell/wayland/model/event/new_surface/new_surface.serializable.dart';
import 'package:shell/wayland/model/event/wayland_event.serializable.dart';
import 'package:shell/wayland/model/request/unregister_view_texture/unregister_view_texture.serializable.dart';
import 'package:shell/wayland/model/surface_manager_state.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/subsurface_state.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';

part 'surface.manager.g.dart';

@Riverpod(keepAlive: true)
class SurfaceManager extends _$SurfaceManager {
  @override
  SurfaceManagerState build() {
    print('SurfaceManager build');

    ref.listen(waylandManagerProvider, (_, next) {
      switch (next) {
        case AsyncData(value: final NewSurfaceEvent event):
          _newSurface(event.message);
        case AsyncData(value: final NewSubsurfaceEvent event):
          _newSubsurface(event.message);
        case AsyncData(value: final CommitSurfaceEvent event):
          _commitSurface(event.message);
        case AsyncData(value: final DestroySurfaceEvent event):
          _destroySurface(event.message);
        case AsyncData(value: final DestroySubsurfaceEvent event):
          _destroySubsurface(event.message);
      }
    });
    return SurfaceManagerState(
      wlSurfaces: ISet(),
      subSurfaces: ISet(),
    );
  }

  /// Send a [UnregisterViewTextureRequest] to the Wayland compositor
  Future<void> unregisterViewTexture(int textureId) {
    return ref.read(waylandManagerProvider.notifier).request(
          UnregisterViewTextureRequest(
            message: UnregisterViewTextureMessage(textureId: textureId),
          ),
        );
  }

  void _newSurface(NewSurfaceMessage message) {
    ref.read(wlSurfaceStateProvider(message.surfaceId).notifier).initialize();
    state = state.copyWith(
      wlSurfaces: state.wlSurfaces.add(message.surfaceId),
    );
  }

  void _newSubsurface(NewSubsurfaceMessage message) {
    ref.read(subsurfaceStateProvider(message.surfaceId).notifier).initialize(
          parent: message.parent,
        );
    state = state.copyWith(
      subSurfaces: state.subSurfaces.add(message.surfaceId),
    );
  }

  void _commitSurface(CommitSurfaceMessage message) {
    final role = switch (message.role) {
      SubsurfaceRoleMessage() => SurfaceRole.subsurface,
      null => null,
    };

    try {
      ref.read(wlSurfaceStateProvider(message.surfaceId));
    } catch (e) {
      // ignore: avoid_print
      print(e);
      return;
    }

    ref.read(wlSurfaceStateProvider(message.surfaceId).notifier).commit(
          role: role,
          textureId: message.textureId,
          surfaceSize: Size(
            message.bufferSize?.width ?? 0.0,
            message.bufferSize?.height ?? 0.0,
          ),
          scale: message.scale,
          subsurfacesBelow: message.subsurfacesBelow,
          subsurfacesAbove: message.subsurfacesAbove,
          inputRegion: message.inputRegion,
        );

    final surfaceRole = message.role;
    switch (surfaceRole) {
      case SubsurfaceRoleMessage():
        ref.read(subsurfaceStateProvider(message.surfaceId).notifier).commit(
              position: surfaceRole.position,
            );
      // Nothing to do.
      case null:
        break;
    }
  }

  Future<void> _destroySurface(DestroySurfaceMessage message) async {
    print('Destroy surface: ${message.surfaceId}');
    assert(state.wlSurfaces.contains(message.surfaceId));

    final wlSurfaceState = ref.read(wlSurfaceStateProvider(message.surfaceId));

    // TODO: Patch Smithay to send destroy events for subsurfaces and xdg surfaces.
    // Especially important for subsurfaces because when a subsurface is destroyed,
    // it must be unmapped immediately.
    if (wlSurfaceState.role == SurfaceRole.subsurface) {
      _destroySubsurface(
        DestroySubsurfaceMessage(surfaceId: message.surfaceId),
      );
    }

    ref.read(wlSurfaceStateProvider(message.surfaceId).notifier).dispose();
    state = state.copyWith(
      wlSurfaces: state.wlSurfaces.remove(message.surfaceId),
    );
  }

  void _destroySubsurface(DestroySubsurfaceMessage message) {
    final parent = ref.read(subsurfaceStateProvider(message.surfaceId)).parent;
    ref
        .read(wlSurfaceStateProvider(parent).notifier)
        .removeSubsurface(message.surfaceId);
    ref.read(subsurfaceStateProvider(message.surfaceId).notifier).dispose();
    state = state.copyWith(
      subSurfaces: state.subSurfaces.remove(message.surfaceId),
    );
  }
}
