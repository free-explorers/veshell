import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/model/xdg_surface.dart';
import 'package:shell/wayland/provider/surface.manager.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';

part 'xdg_surface_state.g.dart';

@riverpod
class XdgSurfaceState extends _$XdgSurfaceState {
  late final KeepAliveLink _keepAliveLink;

  @override
  XdgSurface build(SurfaceId surfaceId) {
    _keepAliveLink = ref.keepAlive();
    ref.onDispose(() {
      print('disposing XdgSurfaceStateProvider $surfaceId');
    });

    // 1. Is a texture attached?
    // 2. Does it have a role?
    ref.listen(
      wlSurfaceStateProvider(surfaceId)
          .select((value) => (value.texture, value.role)),
      (_, __) => _checkIfMapped(),
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

  void _checkIfMapped() {
    final hasTexture =
        ref.read(wlSurfaceStateProvider(surfaceId)).texture != null;
    final role = ref.read(wlSurfaceStateProvider(surfaceId)).role;
    final hasRole = role != null;
    final isCommitted = state.committed;
    final isRoleCommitted = _isRoleCommitted();

    final wasMapped = state.mapped;
    state = state.copyWith(
      mapped: hasTexture && hasRole && isCommitted && isRoleCommitted,
    );

    if (role == SurfaceRole.xdgToplevel) {
      if (!wasMapped && state.mapped) {
        ref.read(newXdgToplevelSurfaceProvider.notifier).mapped(surfaceId);
        print("mapped $surfaceId");
      } else if (wasMapped && !state.mapped) {
        ref.read(newXdgToplevelSurfaceProvider.notifier).unmapped(surfaceId);
      }
    }
  }

  bool _isRoleCommitted() {
    return switch (ref.read(wlSurfaceStateProvider(surfaceId)).role) {
      SurfaceRole.xdgToplevel => state.committed,
      SurfaceRole.xdgPopup => state.committed,
      SurfaceRole.subsurface => false, // unreachable
      null => false,
    };
  }

  void dispose() {
    _keepAliveLink.close();
  }
}
