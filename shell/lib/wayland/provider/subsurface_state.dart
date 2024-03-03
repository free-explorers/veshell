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

  ProviderSubscription<SurfaceRole?>? _parentRoleSub;
  ProviderSubscription<bool>? _parentMappedSub;

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

    ref.listen(
      wlSurfaceStateProvider(surfaceId).select((state) => state.texture),
      (_, __) => _checkIfMapped(),
    );

    _subscribeToParentRole();
  }

  void _subscribeToParentRole() {
    _parentRoleSub?.close();
    _parentRoleSub = ref.listen(
      wlSurfaceStateProvider(state.parent).select((value) => value.role),
      (_, __) => _subscribeToParentMappedProperty(),
    );
    _checkIfMapped();
  }

  void _subscribeToParentMappedProperty() {
    _parentMappedSub?.close();

    _parentMappedSub =
        switch (ref.read(wlSurfaceStateProvider(state.parent)).role) {
      SurfaceRole.xdgToplevel || SurfaceRole.xdgPopup => ref.listen(
          xdgSurfaceStateProvider(state.parent).select(
            (state) => state.mapped,
          ),
          (_, __) => _checkIfMapped(),
        ),
      SurfaceRole.subsurface => ref.listen(
          subsurfaceStateProvider(state.parent).select(
            (state) => state.mapped,
          ),
          (_, __) => _checkIfMapped(),
        ),
      SurfaceRole.x11Surface || null => null,
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
      SurfaceRole.x11Surface || null => false,
    };

    final isCommitted = state.committed;

    state = state.copyWith(
      // A sub-surface becomes mapped, when a non-NULL wl_buffer is applied and the parent surface is mapped.
      // The order of which one happens first is irrelevant.
      // A sub-surface is hidden if the parent becomes hidden, or if a NULL wl_buffer is applied.
      // These rules apply recursively through the tree of surfaces.
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
    _parentRoleSub?.close();
    _parentMappedSub?.close();
    _keepAliveLink.close();
  }
}
