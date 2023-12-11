import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/manager/platform_api/platform_api.provider.dart';
import 'package:shell/manager/surface/subsurface/subsurface.provider.dart';
import 'package:shell/manager/surface/surface/surface.provider.dart';
import 'package:shell/manager/surface/surface_ids.provider.dart';
import 'package:shell/manager/surface/xdg_popup/xdg_popup.provider.dart';
import 'package:shell/manager/surface/xdg_surface/xdg_surface.provider.dart';
import 'package:shell/manager/surface/xdg_toplevel/xdg_toplevel.provider.dart';
import 'package:shell/manager/wayland/event/commit_surface/commit_surface.model.serializable.dart';
import 'package:shell/manager/wayland/event/wayland_event.model.serializable.dart';
import 'package:shell/manager/wayland/request/unregister_view_texture/unregister_view_texture.model.serializable.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';

part 'surface.manager.g.dart';

@Riverpod(keepAlive: true)
class SurfaceManager extends _$SurfaceManager {
  ///
  late final textureFinalizer = Finalizer((int textureId) async {
    // It's possible for a render pass to be late and to use a texture id, even if the object
    // is no longer in memory. Give a generous interval of time for any renders using this texture
    // to finalize.
    await Future<void>.delayed(const Duration(seconds: 1));
    await unregisterViewTexture(textureId);
  });

  @override
  Null build() {
    ref.listen(waylandManagerProvider, (_, next) {
      if (next case AsyncData(value: final CommitSurfaceEvent event)) {
        _commitSurface(event.message);
      }
    });
    return null;
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
    ref
        .read(surfaceIdsProvider.notifier)
        .update((state) => state.add(message.surfaceId));

    // TODO(roscale): Don't remove the late keyword even if it still compiles !
    // If you remove it, it will run correctly in debug mode but not in release mode.
    // I should make a minimum reproducible example and file a bug.
    late TextureId textureId;

    final currentTextureId =
        ref.read(surfaceStatesProvider(message.surfaceId)).textureId;
    if (message.surface.textureId == currentTextureId.value) {
      textureId = currentTextureId;
    } else {
      textureId = TextureId(message.surface.textureId);
      textureFinalizer.attach(textureId, textureId.value, detach: textureId);
    }

    for (final id in message.surface.subsurfacesBelow) {
      ref
          .read(subsurfaceStatesProvider(id).notifier)
          .set_parent(message.surfaceId);
    }

    for (final id in message.surface.subsurfacesAbove) {
      ref
          .read(subsurfaceStatesProvider(id).notifier)
          .set_parent(message.surfaceId);
    }

    ref.read(surfaceStatesProvider(message.surfaceId).notifier).commit(
          role: message.surface.role,
          textureId: textureId,
          surfacePosition: Offset(
            message.surface.bufferDelta?.dx ?? 0.0,
            message.surface.bufferDelta?.dy ?? 0.0,
          ),
          surfaceSize: Size(
            message.surface.bufferSize?.width ?? 0.0,
            message.surface.bufferSize?.height ?? 0.0,
          ),
          scale: message.surface.scale.toDouble(),
          subsurfacesBelow: message.surface.subsurfacesBelow,
          subsurfacesAbove: message.surface.subsurfacesAbove,
          inputRegion: message.surface.inputRegion,
        );

    if (message is XdgToplevelCommitSurfaceMessage) {
      ref.read(xdgSurfaceStatesProvider(message.surfaceId).notifier).commit(
            role: message.role,
            visibleBounds: message.geometry ??
                Rect.fromLTWH(
                  message.surface.bufferDelta?.dx ?? 0.0,
                  message.surface.bufferDelta?.dy ?? 0.0,
                  message.surface.bufferSize?.width ?? 0.0,
                  message.surface.bufferSize?.height ?? 0.0,
                ),
          );

      if (message.title != null) {
        ref
            .read(xdgToplevelStatesProvider(message.surfaceId).notifier)
            .setTitle(message.title!);
      }

      if (message.appId != null) {
        ref
            .read(xdgToplevelStatesProvider(message.surfaceId).notifier)
            .setAppId(message.appId!);
      }
      /* if (event.toplevelDecoration != null) {
      ref
          .read(xdgToplevelStatesProvider(event.surfaceId).notifier)
          .setDecoration(event.toplevelDecoration!);
    } */
    }

    if (message is XdgPopupCommitSurfaceMessage) {
      ref.read(xdgSurfaceStatesProvider(message.surfaceId).notifier).commit(
            role: message.role,
            visibleBounds: message.geometry ??
                Rect.fromLTWH(
                  message.surface.bufferDelta?.dx ?? 0.0,
                  message.surface.bufferDelta?.dy ?? 0.0,
                  message.surface.bufferSize?.width ?? 0.0,
                  message.surface.bufferSize?.height ?? 0.0,
                ),
          );
      // TODO: What to do with the xdgPopup width & height?

      ref.read(xdgPopupStatesProvider(message.surfaceId).notifier).commit(
            parentViewId: message.parentSurfaceId,
            position: message.geometry?.topLeft ?? Offset.zero,
          );
    }

    if (message is SubsurfaceCommitSurfaceMessage) {
      ref.read(subsurfaceStatesProvider(message.surfaceId).notifier).commit(
            position: message.position,
          );
    }
  }
}
