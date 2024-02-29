import 'dart:async';
import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/model/xdg_surface.dart';
import 'package:shell/wayland/provider/surface.manager.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/provider/xdg_popup_state.dart';
import 'package:shell/wayland/provider/xdg_toplevel_state.dart';

part 'xdg_surface_state.g.dart';

@riverpod
class XdgSurfaceState extends _$XdgSurfaceState {
  late final KeepAliveLink _keepAliveLink;

  ProviderSubscription<bool>? roleCommittedSubscription;

  @override
  XdgSurface build(SurfaceId surfaceId) {
    _keepAliveLink = ref.keepAlive();
    ref.onDispose(() {
      print('disposing XdgSurfaceStateProvider $surfaceId');
    });

    // 1. Is a texture attached?
    ref.listen(
      wlSurfaceStateProvider(surfaceId).select((value) => value.texture),
      (_, __) => _checkIfMapped(),
    );

    // 2. Does it have a role?
    ref.listen(
      wlSurfaceStateProvider(surfaceId).select((value) => value.role),
      (_, __) {
        _subscribeToRoleCommittedProperty();
      },
    );

    return XdgSurface(
      mapped: false,
      committed: false,
      geometry: Rect.zero,
      popups: IList(),
    );
  }

  void commit({
    required Rect? geometry,
  }) {
    state = state.copyWith(
      committed: true,
      geometry: geometry,
    );
    _checkIfMapped();
  }

  void addPopup(SurfaceId surfaceId) {
    state = state.copyWith(
      popups: state.popups.add(surfaceId),
    );
  }

  void removePopup(SurfaceId surfaceId) {
    state = state.copyWith(
      popups: state.popups.remove(surfaceId),
    );
  }

  void _subscribeToRoleCommittedProperty() {
    roleCommittedSubscription?.close();

    roleCommittedSubscription =
        switch (ref.read(wlSurfaceStateProvider(surfaceId)).role) {
      SurfaceRole.xdgToplevel => ref.listen(
          xdgToplevelStateProvider(surfaceId).select(
            (value) => value.committed,
          ),
          (_, __) => _checkIfMapped(),
        ),
      SurfaceRole.xdgPopup => ref.listen(
          xdgPopupStateProvider(surfaceId).select(
            (value) => value.committed,
          ),
          (_, __) => _checkIfMapped(),
        ),
      null => null,
      // unreachable
      SurfaceRole.subsurface => null,
    };
  }

  void _checkIfMapped() {
    final role = ref.read(wlSurfaceStateProvider(surfaceId)).role;
    final hasRole = role != null;
    final isCommitted = state.committed;
    final isRoleCommitted = _isRoleCommitted();
    final hasTexture =
        ref.read(wlSurfaceStateProvider(surfaceId)).texture != null;

    final wasMapped = state.mapped;
    state = state.copyWith(
      // For an xdg_surface to be mapped by the compositor, the following conditions must be met:
      // (1) the client has assigned an xdg_surface-based role to the surface
      // (2) the client has set and committed the xdg_surface state and the role-dependent state to the surface
      // (3) the client has committed a buffer to the surface.
      mapped: hasRole && isCommitted && isRoleCommitted && hasTexture,
    );

    if (role == SurfaceRole.xdgToplevel) {
      if (!wasMapped && state.mapped) {
        ref.read(newXdgToplevelSurfaceProvider.notifier).mapped(surfaceId);
      } else if (wasMapped && !state.mapped) {
        ref.read(newXdgToplevelSurfaceProvider.notifier).unmapped(surfaceId);
      }
    }
  }

  bool _isRoleCommitted() {
    return switch (ref.read(wlSurfaceStateProvider(surfaceId)).role) {
      SurfaceRole.xdgToplevel => state.committed,
      SurfaceRole.xdgPopup => state.committed,
      null => false,
      // unreachable
      SurfaceRole.subsurface => false,
    };
  }

  void dispose() {
    roleCommittedSubscription?.close();
    _keepAliveLink.close();
  }
}
