import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/subsurface.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/provider/xdg_surface_state.dart';

part 'subsurface_state.g.dart';

@riverpod
class SubsurfaceState extends _$SubsurfaceState {
  late final KeepAliveLink _keepAliveLink;

  ProviderSubscription<SurfaceRole>? parentRoleSub;
  ProviderSubscription<bool>? parentMappedSub;

  @override
  Subsurface build(SurfaceId surfaceId) {
    throw Exception('Subsurface $surfaceId state was not initialized');
  }

  void initialize({
    required SurfaceId parent,
    required Offset position,
  }) {
    _keepAliveLink = ref.keepAlive();
    ref.onDispose(() {
      print('disposing SubsurfaceStateProvider $surfaceId');
    });

    state = Subsurface(
      mapped: false,
      parent: parent,
      position: position,
    );

    ref
      ..listen(
        wlSurfaceStateProvider(surfaceId).select((state) => state.textureId),
        (_, __) => _checkIfMapped(),
      )
      ..listen(
        wlSurfaceStateProvider(state.parent),
        (_, __) => _checkIfMapped(),
      );
  }

  void _checkIfMapped() {
    // TODO(roscale): Make textureId nullable instead of -1.
    final hasTexture =
        ref.read(wlSurfaceStateProvider(surfaceId)).textureId != -1;

    final parentMapped =
        switch (ref.read(wlSurfaceStateProvider(state.parent)).role) {
      SurfaceRole.xdgToplevel ||
      SurfaceRole.xdgPopup =>
        ref.read(xdgSurfaceStateProvider(state.parent)).mapped,
      SurfaceRole.subsurface =>
        ref.read(subsurfaceStateProvider(state.parent)).mapped,
    };

    state = state.copyWith(
      mapped: hasTexture && parentMapped,
    );
  }

  void setParent(int parent) {
    state = state.copyWith(
      parent: parent,
    );
    _checkIfMapped();

    // if (!ref.read(surfaceManagerProvider).contains(parent)) {
    //   parentRoleSub?.close();
    //   parentMappedSub?.close();
    //   return;
    // }
    //
    // parentRoleSub?.close();
    /* parentRoleSub = ref.listen(
      wlSurfaceStateProvider(parent).select((value) => value.role),
      (_, __) => _checkIfMapped(),
    ); */

    // parentMappedSub?.close();
    // print("$surfaceId, parent: $parent");
    /*final role = ref.read(wlSurfaceStateProvider(parent)).role;
     switch (role) {
      case SurfaceRole.xdgTopLevel:
      case SurfaceRole.xdgPopup:
        parentMappedSub = ref.listen(
          xdgSurfaceStatesProvider(parent).select((state) => state.mapped),
          (_, __) => _checkIfMapped(),
        );
      case SurfaceRole.subsurface:
        parentMappedSub = ref.listen(
          subsurfaceStatesProvider(parent).select((state) => state.mapped),
          (_, __) => _checkIfMapped(),
        );
      case SurfaceRole.none:
      case SurfaceRole.cursorImage:
    } */
  }

  void commit({required Offset position}) {
    state = state.copyWith(
      position: position,
    );
  }

  void dispose() {
    ref.invalidateSelf();
  }
}
