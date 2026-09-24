import 'dart:async';
import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/platform/model/event/commit_surface/commit_surface.serializable.dart';
import 'package:shell/platform/model/event/destroy_subsurface/destroy_subsurface.serializable.dart';
import 'package:shell/platform/model/event/destroy_surface/destroy_surface.serializable.dart';
import 'package:shell/platform/model/event/new_subsurface/new_subsurface.serializable.dart';
import 'package:shell/platform/model/event/new_surface/new_surface.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/model/request/unregister_view_texture/unregister_view_texture.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/wayland/model/surface_manager_state.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/subsurface_state.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/shared/util/logger.dart';

part 'surface.manager.g.dart';

@riverpod
class SurfaceManager extends _$SurfaceManager {
  @override
  SurfaceManagerState build() {
    print('SurfaceManager build');

    ref.watch(platformManagerProvider).listen((next) {
      switch (next) {
        case final NewSurfaceEvent event:
          _newSurface(event.message);
        case final NewSubsurfaceEvent event:
          _newSubsurface(event.message);
        case final CommitSurfaceEvent event:
          _commitSurface(event.message);
        case final DestroySurfaceEvent event:
          _destroySurface(event.message);
        case final DestroySubsurfaceEvent event:
          _destroySubsurface(event.message);
        case _:
          break;
      }
    });
    return SurfaceManagerState(wlSurfaces: ISet(), subSurfaces: ISet());
  }

  /// Send a [UnregisterViewTextureRequest] to the Wayland compositor
  Future<void> unregisterViewTexture(int textureId) {
    return ref
        .read(platformManagerProvider.notifier)
        .request(
          UnregisterViewTextureRequest(
            message: UnregisterViewTextureMessage(textureId: textureId),
          ),
        );
  }

  void _newSurface(NewSurfaceMessage message) {
    ref.read(wlSurfaceStateProvider(message.surfaceId).notifier).initialize();
    state = state.copyWith(wlSurfaces: state.wlSurfaces.add(message.surfaceId));
  }

  void _newSubsurface(NewSubsurfaceMessage message) {
    ref
        .read(subsurfaceStateProvider(message.surfaceId).notifier)
        .initialize(parent: message.parent);
    state = state.copyWith(
      subSurfaces: state.subSurfaces.add(message.surfaceId),
    );
  }

  void _commitSurface(CommitSurfaceMessage message) {
    geometryLog.info(
      'surface commit surface=${message.surfaceId} '
      'texture=${message.textureId} buffer=${message.bufferSize} '
      'scale=${message.scale} role=${message.role} '
      'input=${message.inputRegion} '
      'below=${message.subsurfacesBelow} above=${message.subsurfacesAbove}',
    );
    final role = switch (message.role) {
      SubsurfaceRoleMessage() => SurfaceRole.subsurface,
      null => null,
    };

    ref
        .read(wlSurfaceStateProvider(message.surfaceId).notifier)
        .commit(
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
        ref
            .read(subsurfaceStateProvider(message.surfaceId).notifier)
            .commit(position: surfaceRole.position);
      // Nothing to do.
      case null:
        break;
    }
  }

  Future<void> _destroySurface(DestroySurfaceMessage message) async {
    print('Destroy surface: ${message.surfaceId}');
    assert(state.wlSurfaces.contains(message.surfaceId));

    final wlSurfaceState = ref.read(wlSurfaceStateProvider(message.surfaceId));

    // The compositor may commit or destroy surfaces the shell never received
    // a `new_surface` for, and their state providers can fail to tear down.
    // Contain the damage to that one surface so the manager keeps working.
    try {
      // TODO: Patch Smithay to send destroy events for subsurfaces and xdg surfaces.
      // Especially important for subsurfaces because when a subsurface is destroyed,
      // it must be unmapped immediately.
      if (wlSurfaceState.role == SurfaceRole.subsurface) {
        _destroySubsurface(
          DestroySubsurfaceMessage(surfaceId: message.surfaceId),
        );
      }
    } on Object catch (error, stackTrace) {
      geometryLog.warning(
        'destroy surface=${message.surfaceId} subsurface teardown failed',
        error,
        stackTrace,
      );
    }

    try {
      ref.read(wlSurfaceStateProvider(message.surfaceId).notifier).dispose();
    } on Object catch (error, stackTrace) {
      geometryLog.warning(
        'surface=${message.surfaceId} dispose failed',
        error,
        stackTrace,
      );
    }

    state = state.copyWith(
      wlSurfaces: state.wlSurfaces.remove(message.surfaceId),
    );
  }

  void _destroySubsurface(DestroySubsurfaceMessage message) {
    try {
      final parent = ref
          .read(subsurfaceStateProvider(message.surfaceId))
          .parent;
      ref
          .read(wlSurfaceStateProvider(parent).notifier)
          .removeSubsurface(message.surfaceId);
    } on Object catch (error, stackTrace) {
      geometryLog.warning(
        'destroy subsurface=${message.surfaceId} parent removal failed',
        error,
        stackTrace,
      );
    }

    try {
      ref.read(subsurfaceStateProvider(message.surfaceId).notifier).dispose();
    } on Object catch (error, stackTrace) {
      geometryLog.warning(
        'subsurface=${message.surfaceId} dispose failed',
        error,
        stackTrace,
      );
    }

    state = state.copyWith(
      subSurfaces: state.subSurfaces.remove(message.surfaceId),
    );
  }
}
