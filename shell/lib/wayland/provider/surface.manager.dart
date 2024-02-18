import 'dart:async';
import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/event/commit_surface/commit_surface.serializable.dart';
import 'package:shell/wayland/model/event/destroy_surface/destroy_surface.serializable.dart';
import 'package:shell/wayland/model/event/wayland_event.serializable.dart';
import 'package:shell/wayland/model/request/unregister_view_texture/unregister_view_texture.serializable.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/subsurface_state.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/provider/xdg_popup_state.dart';
import 'package:shell/wayland/provider/xdg_surface_state.dart';
import 'package:shell/wayland/provider/xdg_toplevel_state.dart';

part 'surface.manager.g.dart';

@Riverpod(keepAlive: true)
class SurfaceManager extends _$SurfaceManager {
  @override
  ISet<int> build() {
    ref.listen(waylandManagerProvider, (_, next) {
      if (next case AsyncData(value: final CommitSurfaceEvent event)) {
        _commitSurface(event.message);
      }
      if (next case AsyncData(value: final DestroySurfaceEvent event)) {
        _destroySurface(event.message);
      }
    });
    return ISet<int>();
  }

  /// Send a [UnregisterViewTextureRequest] to the Wayland compositor
  Future<void> unregisterViewTexture(int textureId) {
    return ref.read(waylandManagerProvider.notifier).request(
          UnregisterViewTextureRequest(
            message: UnregisterViewTextureMessage(textureId: textureId),
          ),
        );
  }

  void _commitSurface(CommitSurfaceMessage message) {
    final isNewSurface = !state.contains(message.surfaceId);
    if (isNewSurface) {
      _onNewSurface(message);
      return;
    }

    for (final id in message.subsurfacesBelow) {
      ref
          .read(subsurfaceStateProvider(id).notifier)
          .set_parent(message.surfaceId);
    }

    for (final id in message.subsurfacesAbove) {
      ref
          .read(subsurfaceStateProvider(id).notifier)
          .set_parent(message.surfaceId);
    }

    final role = switch (message.role) {
      XdgSurfaceRoleMessage(:final role) => switch (role) {
          XdgToplevelMessage() => SurfaceRole.xdgToplevel,
          XdgPopupMessage() => SurfaceRole.xdgPopup,
        },
      SubsurfaceRoleMessage() => SurfaceRole.subsurface,
    };

    ref.read(wlSurfaceStateProvider(message.surfaceId).notifier).commit(
          role: role,
          textureId: message.textureId,
          surfacePosition: Offset(
            message.bufferDelta?.dx ?? 0.0,
            message.bufferDelta?.dy ?? 0.0,
          ),
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
      case XdgSurfaceRoleMessage(:final role):
        ref.read(xdgSurfaceStateProvider(message.surfaceId).notifier).commit(
              geometry: surfaceRole.geometry,
            );

        switch (role) {
          case XdgToplevelMessage():
            ref
                .read(xdgToplevelStateProvider(message.surfaceId).notifier)
                .onCommit(
                  parent: role.parent,
                  appId: role.appId,
                  title: role.title,
                );
          case XdgPopupMessage():
            ref
                .read(xdgPopupStateProvider(message.surfaceId).notifier)
                .onCommit(
                  parent: role.parent,
                  position: role.position,
                );
        }
      case SubsurfaceRoleMessage():
        ref.read(subsurfaceStateProvider(message.surfaceId).notifier).commit(
              position: surfaceRole.position,
            );
    }
  }

  void _onNewSurface(CommitSurfaceMessage message) {
    print('New surface: ${message.surfaceId} ${message.role}');

    state = state.add(message.surfaceId);

    final role = switch (message.role) {
      XdgSurfaceRoleMessage(:final role) => switch (role) {
          XdgToplevelMessage() => SurfaceRole.xdgToplevel,
          XdgPopupMessage() => SurfaceRole.xdgPopup,
        },
      SubsurfaceRoleMessage() => SurfaceRole.subsurface,
    };

    ref.read(wlSurfaceStateProvider(message.surfaceId).notifier).initialize(
          surfaceId: message.surfaceId,
          role: role,
          textureId: message.textureId,
          scale: message.scale,
          inputRegion: message.inputRegion,
          subsurfacesBelow: message.subsurfacesBelow,
          subsurfacesAbove: message.subsurfacesAbove,
          bufferDelta: message.bufferDelta,
          bufferSize: message.bufferSize,
        );

    final surfaceRole = message.role;
    switch (surfaceRole) {
      case XdgSurfaceRoleMessage(:final role):
        ref
            .read(xdgSurfaceStateProvider(message.surfaceId).notifier)
            .initialize(
              geometry: surfaceRole.geometry,
            );

        switch (role) {
          case XdgToplevelMessage():
            ref
                .read(xdgToplevelStateProvider(message.surfaceId).notifier)
                .initialize(
                  parent: role.parent,
                  appId: role.appId,
                  title: role.title,
                );
            ref.read(newXdgToplevelSurfaceProvider.notifier).notify(
                  message.surfaceId,
                );

          case XdgPopupMessage():
            ref
                .read(xdgPopupStateProvider(message.surfaceId).notifier)
                .initialize(
                  parent: role.parent,
                  position: role.position,
                );

            ref
                .read(xdgSurfaceStateProvider(role.parent).notifier)
                .addPopup(message.surfaceId);
        }

      case SubsurfaceRoleMessage():
      // TODO: implement subsurface
    }
  }

  Future<void> _destroySurface(DestroySurfaceMessage message) async {
    print('Destroy surface: ${message.surfaceId}');
    if (!state.contains(message.surfaceId)) {
      return;
    }
    final wlSurfaceState = ref.read(wlSurfaceStateProvider(message.surfaceId));
    ref.read(wlSurfaceStateProvider(message.surfaceId).notifier).dispose();

    switch (wlSurfaceState.role) {
      case SurfaceRole.xdgToplevel:
        ref
            .read(xdgToplevelStateProvider(message.surfaceId).notifier)
            .dispose();
      case SurfaceRole.xdgPopup:
        final popup = ref.read(xdgPopupStateProvider(message.surfaceId));
        ref
            .read(xdgSurfaceStateProvider(popup.parent).notifier)
            .removePopup(message.surfaceId);
        ref.read(xdgPopupStateProvider(message.surfaceId).notifier).dispose();
      case SurfaceRole.subsurface:
        ref.read(subsurfaceStateProvider(message.surfaceId).notifier).dispose();
    }
    state = state.remove(message.surfaceId);
  }
}

@Riverpod(keepAlive: true)
class NewXdgToplevelSurface extends _$NewXdgToplevelSurface {
  final _streamController = StreamController<int>();

  /// Build the stream of [int]
  @override
  Stream<int> build() {
    return _streamController.stream;
  }

  void notify(SurfaceId surfaceId) {
    _streamController.sink.add(surfaceId);
  }
}
