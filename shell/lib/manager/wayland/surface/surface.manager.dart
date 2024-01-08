import 'dart:async';
import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/manager/wayland/event/commit_surface/commit_surface.model.serializable.dart';
import 'package:shell/manager/wayland/event/destroy_surface/destroy_surface.model.serializable.dart';
import 'package:shell/manager/wayland/event/wayland_event.model.serializable.dart';
import 'package:shell/manager/wayland/request/unregister_view_texture/unregister_view_texture.model.serializable.dart';
import 'package:shell/manager/wayland/surface/subsurface/subsurface.provider.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.provider.dart';
import 'package:shell/manager/wayland/surface/xdg_surface/xdg_popup.provider.dart';
import 'package:shell/manager/wayland/surface/xdg_surface/xdg_toplevel.provider.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';

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

    if (message.surface != null) {
      final surface = message.surface!;

      for (final id in surface.subsurfacesBelow) {
        ref
            .read(subsurfaceStatesProvider(id).notifier)
            .set_parent(message.surfaceId);
      }

      for (final id in surface.subsurfacesAbove) {
        ref
            .read(subsurfaceStatesProvider(id).notifier)
            .set_parent(message.surfaceId);
      }

      ref.read(wlSurfaceStateProvider(message.surfaceId).notifier).commit(
            role: message.role,
            textureId: surface.textureId,
            surfacePosition: Offset(
              surface.bufferDelta?.dx ?? 0.0,
              surface.bufferDelta?.dy ?? 0.0,
            ),
            surfaceSize: Size(
              surface.bufferSize?.width ?? 0.0,
              surface.bufferSize?.height ?? 0.0,
            ),
            scale: surface.scale,
            subsurfacesBelow: surface.subsurfacesBelow,
            subsurfacesAbove: surface.subsurfacesAbove,
            inputRegion: surface.inputRegion,
          );
    }

    if (message is XdgToplevelCommitSurfaceMessage) {
      ref
          .read(xdgToplevelStateProvider(message.surfaceId).notifier)
          .onCommit(message);
    }

    if (message is XdgPopupCommitSurfaceMessage) {
      ref.read(xdgPopupStateProvider(message.surfaceId).notifier).onCommit(
            message,
          );
    }

    if (message is SubsurfaceCommitSurfaceMessage) {
      ref.read(subsurfaceStatesProvider(message.surfaceId).notifier).commit(
            position: message.position,
          );
    }
  }

  void _onNewSurface(CommitSurfaceMessage message) {
    print('New surface: ${message.surfaceId} ${message.role}');
    if (message.surface == null) {
      return;
    }
    state = state.add(message.surfaceId);
    ref.read(wlSurfaceStateProvider(message.surfaceId).notifier).initialize(
          message,
        );

    if (message is XdgToplevelCommitSurfaceMessage) {
      ref.read(xdgToplevelStateProvider(message.surfaceId).notifier).initialize(
            message,
          );

      ref.read(newXdgToplevelSurfaceProvider.notifier).notify(
            message.surfaceId,
          );
    }

    if (message is XdgPopupCommitSurfaceMessage) {
      if (message.parentSurfaceId == null) {
        print('Parent surface is null: ${message.surfaceId} ${message.role}');

        return;
      }
      ref.read(xdgPopupStateProvider(message.surfaceId).notifier).initialize(
            message,
          );
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
      case SurfaceRole.xdgTopLevel:
        ref
            .read(xdgToplevelStateProvider(message.surfaceId).notifier)
            .dispose();
      case SurfaceRole.xdgPopup:
        ref.read(xdgPopupStateProvider(message.surfaceId).notifier).dispose();
      case SurfaceRole.subsurface:
        ref
            .read(subsurfaceStatesProvider(message.surfaceId).notifier)
            .dispose();
      case SurfaceRole.none:
      case SurfaceRole.cursorImage:
        break;
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

@Riverpod(keepAlive: true)
class PopupListForSurface extends _$PopupListForSurface {
  @override
  IMapOfSets<SurfaceId, SurfaceId> build() {
    return IMapOfSets();
  }

  void add(SurfaceId parentSurfaceId, SurfaceId surfaceId) {
    final rootParent =
        state.getKeyWithValue(parentSurfaceId) ?? parentSurfaceId;
    state = state.add(rootParent, surfaceId);
  }

  void remove(SurfaceId parentSurfaceId, SurfaceId surfaceId) {
    final rootParent =
        state.getKeyWithValue(parentSurfaceId) ?? parentSurfaceId;
    state = state.remove(rootParent, surfaceId);
  }
}
