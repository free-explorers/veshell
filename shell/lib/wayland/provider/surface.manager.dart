import 'dart:async';
import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/event/app_id_changed/app_id_changed.serializable.dart';
import 'package:shell/wayland/model/event/commit_surface/commit_surface.serializable.dart';
import 'package:shell/wayland/model/event/destroy_popup/destroy_popup.serializable.dart';
import 'package:shell/wayland/model/event/destroy_subsurface/destroy_subsurface.serializable.dart';
import 'package:shell/wayland/model/event/destroy_surface/destroy_surface.serializable.dart';
import 'package:shell/wayland/model/event/destroy_toplevel/destroy_toplevel.serializable.dart';
import 'package:shell/wayland/model/event/destroy_x11_surface/destroy_x11_surface.serializable.dart';
import 'package:shell/wayland/model/event/destroy_xdg_surface/destroy_xdg_surface.serializable.dart';
import 'package:shell/wayland/model/event/map_x11_surface/map_x11_surface.serializable.dart';
import 'package:shell/wayland/model/event/new_popup/new_popup.serializable.dart';
import 'package:shell/wayland/model/event/new_subsurface/new_subsurface.serializable.dart';
import 'package:shell/wayland/model/event/new_surface/new_surface.serializable.dart';
import 'package:shell/wayland/model/event/new_toplevel/new_toplevel.serializable.dart';
import 'package:shell/wayland/model/event/new_x11_surface/new_x11_surface.serializable.dart';
import 'package:shell/wayland/model/event/surface_associated/surface_associated.serializable.dart';
import 'package:shell/wayland/model/event/title_changed/title_changed.serializable.dart';
import 'package:shell/wayland/model/event/unmap_x11_surface/unmap_x11_surface.serializable.dart';
import 'package:shell/wayland/model/event/wayland_event.serializable.dart';
import 'package:shell/wayland/model/event/x11_properties_changed/x11_properties_changed.serializable.dart';
import 'package:shell/wayland/model/request/unregister_view_texture/unregister_view_texture.serializable.dart';
import 'package:shell/wayland/model/surface_manager_state.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/subsurface_state.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/provider/x11_surface_state.dart';
import 'package:shell/wayland/provider/xdg_popup_state.dart';
import 'package:shell/wayland/provider/xdg_surface_state.dart';
import 'package:shell/wayland/provider/xdg_toplevel_state.dart';
import 'package:shell/window/provider/window_properties.dart';

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
        case AsyncData(value: final NewX11SurfaceEvent event):
          _newX11Surface(event.message);
        case AsyncData(value: final NewToplevelEvent event):
          _newToplevel(event.message);
        case AsyncData(value: final NewPopupEvent event):
          _newPopup(event.message);
        case AsyncData(value: final NewSubsurfaceEvent event):
          _newSubsurface(event.message);
        case AsyncData(value: final CommitSurfaceEvent event):
          _commitSurface(event.message);
        case AsyncData(value: final MapX11SurfaceEvent event):
          _mapX11Surface(event.message);
        case AsyncData(value: final UnmapX11SurfaceEvent event):
          _unmapX11Surface(event.message);
        case AsyncData(value: final X11PropertiesChangedEvent event):
          _x11PropertiesChanged(event.message);
        case AsyncData(value: final SurfaceAssociatedEvent event):
          _surfaceAssociated(event.message);
        case AsyncData(value: final DestroyX11SurfaceEvent event):
          _destroyX11Surface(event.message);
        case AsyncData(value: final DestroySurfaceEvent event):
          _destroySurface(event.message);
        case AsyncData(value: final DestroySubsurfaceEvent event):
          _destroySubsurface(event.message);
        case AsyncData(value: final DestroyToplevelEvent event):
          _destroyToplevel(event.message);
        case AsyncData(value: final DestroyPopupEvent event):
          _destroyPopup(event.message);
        case AsyncData(value: final AppIdChangedEvent event):
          _appIdChanged(event.message);
        case AsyncData(value: final TitleChangedEvent event):
          _titleChanged(event.message);
      }
    });
    return SurfaceManagerState(
      wlSurfaces: ISet(),
      xdgTopLevelSurfaces: ISet(),
      xdgPopupSurfaces: ISet(),
      subSurfaces: ISet(),
      x11Surfaces: ISet(),
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

  void _newX11Surface(NewX11SurfaceMessage message) {
    ref.read(x11SurfaceStateProvider(message.x11SurfaceId).notifier).initialize(
          overrideRedirect: message.overrideRedirect,
        );

    state = state.copyWith(
      x11Surfaces: state.x11Surfaces.add(message.x11SurfaceId),
    );
  }

  void _newToplevel(NewToplevelMessage message) {
    ref
        .read(xdgToplevelStateProvider(message.surfaceId).notifier)
        .initialize(message.pid);
    state = state.copyWith(
      xdgTopLevelSurfaces: state.xdgTopLevelSurfaces.add(message.surfaceId),
    );
  }

  void _newPopup(NewPopupMessage message) {
    ref.read(xdgPopupStateProvider(message.surfaceId).notifier).initialize(
          parent: message.parent,
          position: message.position,
        );
    state = state.copyWith(
      xdgPopupSurfaces: state.xdgPopupSurfaces.add(message.surfaceId),
    );
    ref
        .read(xdgSurfaceStateProvider(message.parent).notifier)
        .addPopup(message.surfaceId);
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
      XdgSurfaceRoleMessage(:final role) => switch (role) {
          XdgToplevelMessage() => SurfaceRole.xdgToplevel,
          XdgPopupMessage() => SurfaceRole.xdgPopup,
          null => null,
        },
      SubsurfaceRoleMessage() => SurfaceRole.subsurface,
      X11SurfaceRoleMessage() => SurfaceRole.x11Surface,
      null => null,
    };

    try {
      ref.read(wlSurfaceStateProvider(message.surfaceId));
    } catch (e, stackTrace) {
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
      case XdgSurfaceRoleMessage(:final role):
        // We need to double check that the surface is still an xdgSurface because sometime a surface can be removed from xdg but still be a wlSurface
        if (!state.xdgTopLevelSurfaces.contains(message.surfaceId) &&
            !state.xdgPopupSurfaces.contains(message.surfaceId)) {
          break;
        }
        ref.read(xdgSurfaceStateProvider(message.surfaceId).notifier).commit(
              geometry: surfaceRole.geometry,
            );

        switch (role) {
          case XdgToplevelMessage():
            ref
                .read(xdgToplevelStateProvider(message.surfaceId).notifier)
                .onCommit(
                  parent: role.parentSurfaceId,
                  appId: role.appId,
                  title: role.title,
                );

            ref.read(windowPropertiesStateProvider(message.surfaceId).notifier)
              ..setTitle(role.title)
              ..setAppId(role.appId ?? '');

          case XdgPopupMessage():
            ref
                .read(xdgPopupStateProvider(message.surfaceId).notifier)
                .onCommit(
                  parent: role.parent,
                  position: role.position,
                );
          case null:
          // Nothing to do.
        }
      case SubsurfaceRoleMessage():
        ref.read(subsurfaceStateProvider(message.surfaceId).notifier).commit(
              position: surfaceRole.position,
            );
      case X11SurfaceRoleMessage() || null:
      // Nothing to do.
    }
  }

  void _mapX11Surface(MapX11SurfaceMessage message) {
    ref
        .read(x11SurfaceStateProvider(message.x11SurfaceId).notifier)
        .map(parent: message.parent, geometry: message.geometry);
  }

  void _unmapX11Surface(UnmapX11SurfaceMessage message) {
    ref.read(x11SurfaceStateProvider(message.x11SurfaceId).notifier).unmap();
  }

  void _x11PropertiesChanged(X11PropertiesChangedMessage message) {
    try {
      ref.read(x11SurfaceStateProvider(message.x11SurfaceId));
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print(e);
      return;
    }
    ref
        .read(x11SurfaceStateProvider(message.x11SurfaceId).notifier)
        .setProperties(
          title: message.title,
          windowClass: message.windowClass,
          instance: message.instance,
          startupId: message.startupId,
          pid: message.pid,
        );
  }

  void _surfaceAssociated(SurfaceAssociatedMessage message) {
    ref
        .read(x11SurfaceStateProvider(message.x11SurfaceId).notifier)
        .associate(message.surfaceId);
  }

  void _destroyX11Surface(DestroyX11SurfaceMessage message) {
    ref.read(x11SurfaceStateProvider(message.x11SurfaceId).notifier).dispose();
    state = state.copyWith(
      x11Surfaces: state.x11Surfaces.remove(message.x11SurfaceId),
    );
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

  void _destroyXdgSurface(DestroyXdgSurfaceMessage message) {
    ref.read(xdgSurfaceStateProvider(message.surfaceId).notifier).dispose();
  }

  void _destroyToplevel(DestroyToplevelMessage message) {
    _destroyXdgSurface(
      DestroyXdgSurfaceMessage(surfaceId: message.surfaceId),
    );
    ref.read(xdgToplevelStateProvider(message.surfaceId).notifier).dispose();
    state = state.copyWith(
      xdgTopLevelSurfaces: state.xdgTopLevelSurfaces.remove(message.surfaceId),
    );
  }

  void _destroyPopup(DestroyPopupMessage message) {
    _destroyXdgSurface(
      DestroyXdgSurfaceMessage(surfaceId: message.surfaceId),
    );
    final parent = ref.read(xdgPopupStateProvider(message.surfaceId)).parent;
    ref
        .read(xdgSurfaceStateProvider(parent).notifier)
        .removePopup(message.surfaceId);
    ref.read(xdgPopupStateProvider(message.surfaceId).notifier).dispose();
    state = state.copyWith(
      xdgPopupSurfaces: state.xdgPopupSurfaces.remove(message.surfaceId),
    );
  }

  void _appIdChanged(AppIdChangedMessage message) {
    final role = ref.read(wlSurfaceStateProvider(message.surfaceId)).role;

    switch (role) {
      // TODO: Why is the role null?
      case SurfaceRole.xdgToplevel || null:
        ref
            .read(xdgToplevelStateProvider(message.surfaceId).notifier)
            .setAppId(message.appId);
      case SurfaceRole.x11Surface:
        final x11SurfaceId =
            ref.read(x11SurfaceIdByWlSurfaceIdProvider(message.surfaceId));
        ref
            .read(x11SurfaceStateProvider(x11SurfaceId).notifier)
            .setAppId(message.appId ?? '');
      default:
        assert(false);
    }

    ref
        .read(windowPropertiesStateProvider(message.surfaceId).notifier)
        .setAppId(message.appId ?? '');
  }

  void _titleChanged(TitleChangedMessage message) {
    final role = ref.read(wlSurfaceStateProvider(message.surfaceId)).role;

    switch (role) {
      // TODO: Why is the role null?
      case SurfaceRole.xdgToplevel || null:
        ref
            .read(xdgToplevelStateProvider(message.surfaceId).notifier)
            .setTitle(message.title);
      case SurfaceRole.x11Surface:
        final x11SurfaceId =
            ref.read(x11SurfaceIdByWlSurfaceIdProvider(message.surfaceId));
        ref
            .read(x11SurfaceStateProvider(x11SurfaceId).notifier)
            .setTitle(message.title ?? '');
      default:
        assert(false);
    }

    ref
        .read(windowPropertiesStateProvider(message.surfaceId).notifier)
        .setTitle(message.title);
  }
}

sealed class SurfaceMapEvent {
  SurfaceMapEvent(this.surfaceId);

  final SurfaceId surfaceId;
}

class SurfaceMappedEvent extends SurfaceMapEvent {
  SurfaceMappedEvent(super.surfaceId);
}

class SurfaceUnmappedEvent extends SurfaceMapEvent {
  SurfaceUnmappedEvent(super.surfaceId);
}

@Riverpod(keepAlive: true)
class SurfaceMapped extends _$SurfaceMapped {
  final _streamController = StreamController<SurfaceMapEvent>();
  ISet<SurfaceId> _mappedSurfaceSet = ISet<SurfaceId>();

  /// Build the stream of [SurfaceMapEvent]
  @override
  Stream<SurfaceMapEvent> build() {
    return _streamController.stream;
  }

  void mapped(SurfaceId surfaceId) {
    _mappedSurfaceSet = _mappedSurfaceSet.add(surfaceId);
    _streamController.sink.add(SurfaceMappedEvent(surfaceId));
  }

  void unmapped(SurfaceId surfaceId) {
    _mappedSurfaceSet = _mappedSurfaceSet.remove(surfaceId);
    _streamController.sink.add(SurfaceUnmappedEvent(surfaceId));
  }

  /// Return the set of mapped surface ids.
  ISet<SurfaceId> getMappedSurfaceSet() {
    return _mappedSurfaceSet;
  }
}
