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

  ProviderSubscription<SurfaceRole?>? parentRoleSub;
  ProviderSubscription<bool>? parentMappedSub;

  @override
  Subsurface build(SurfaceId surfaceId) {
    throw Exception('Subsurface $surfaceId state was not initialized');
  }

  void initialize({
    required SurfaceId parent,
  }) {
    _keepAliveLink = ref.keepAlive();
    ref.onDispose(() {
      print('disposing SubsurfaceStateProvider $surfaceId');
    });

    state = Subsurface(
      mapped: false,
      committed: false,
      parent: parent,
      position: Offset.zero,
    );

    // 1. Is a texture attached?
    ref.listen(
      wlSurfaceStateProvider(surfaceId).select((state) => state.texture),
      (_, __) => _checkIfMapped(),
    );

    // 2. Is the parent mapped?
    // For this, we have to listen to changes in parent's role
    // and its mapped state.
    _subscribeToParentRole();
  }

  void _subscribeToParentRole() {
    parentRoleSub?.close();
    parentRoleSub = ref.listen(
      wlSurfaceStateProvider(state.parent).select((value) => value.role),
      (_, __) => _subscribeToParentMappedProperty(),
    );
    _checkIfMapped();
  }

  void _subscribeToParentMappedProperty() {
    parentMappedSub?.close();
    parentMappedSub =
        switch (ref.read(wlSurfaceStateProvider(state.parent)).role) {
      SurfaceRole.xdgToplevel || SurfaceRole.xdgPopup => ref.listen(
          xdgSurfaceStateProvider(state.parent).select((state) => state.mapped),
          (_, __) => _checkIfMapped(),
        ),
      SurfaceRole.subsurface => ref.listen(
          subsurfaceStateProvider(state.parent).select((state) => state.mapped),
          (_, __) => _checkIfMapped(),
        ),
      null => null,
    };
    _checkIfMapped();
  }

  void _checkIfMapped() {
    final hasTexture =
        ref.read(wlSurfaceStateProvider(surfaceId)).texture != null;

    final parentMapped =
        switch (ref.read(wlSurfaceStateProvider(state.parent)).role) {
      SurfaceRole.xdgToplevel ||
      SurfaceRole.xdgPopup =>
        ref.read(xdgSurfaceStateProvider(state.parent)).mapped,
      SurfaceRole.subsurface =>
        ref.read(subsurfaceStateProvider(state.parent)).mapped,
      null => false,
    };

    final isCommitted = state.committed;

    state = state.copyWith(
      mapped: hasTexture && isCommitted && parentMapped,
    );
  }

  void setParent(int parent) {
    state = state.copyWith(
      parent: parent,
    );
    _subscribeToParentRole();
  }

  void commit({required Offset position}) {
    state = state.copyWith(
      committed: true,
      position: position,
    );
    _checkIfMapped();
  }

  void dispose() {
    parentRoleSub?.close();
    parentMappedSub?.close();
    _keepAliveLink.close();
  }
}
