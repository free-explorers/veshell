import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/manager/platform_api/platform_event.model.serializable.dart';
import 'package:shell/shared/wayland/subsurface/subsurface.dart';
import 'package:shell/shared/wayland/subsurface/subsurface.model.dart';
import 'package:shell/shared/wayland/surface/surface.provider.dart';
import 'package:shell/shared/wayland/surface_ids.provider.dart';
import 'package:shell/shared/wayland/xdg_surface/xdg_surface.provider.dart';

part 'subsurface.provider.g.dart';

@Riverpod(keepAlive: true)
SubsurfaceWidget subsurfaceWidget(SubsurfaceWidgetRef ref, int surfaceId) {
  return SubsurfaceWidget(
    key: ref.watch(
      subsurfaceStatesProvider(surfaceId).select((state) => state.widgetKey),
    ),
    surfaceId: surfaceId,
  );
}

@Riverpod(keepAlive: true)
class SubsurfaceStates extends _$SubsurfaceStates {
  ProviderSubscription<SurfaceRole>? parentRoleSub;
  ProviderSubscription<bool>? parentMappedSub;

  @override
  SubsurfaceState build(int surfaceId) {
    ref.listen(
      surfaceStatesProvider(surfaceId).select((state) => state.textureId),
      (_, __) => _checkIfMapped(),
    );
    ref.listen(surfaceIdsProvider, (_, __) => _checkIfMapped());

    return SubsurfaceState(
      mapped: false,
      parent: 0,
      position: Offset.zero,
      widgetKey: GlobalKey(),
    );
  }

  void _checkIfMapped() {
    var parentMapped = false;
    if (ref.read(surfaceIdsProvider).contains(state.parent)) {
      final role = ref.read(surfaceStatesProvider(state.parent)).role;
      switch (role) {
        case SurfaceRole.xdgSurface:
          parentMapped =
              ref.read(xdgSurfaceStatesProvider(state.parent)).mapped;
        case SurfaceRole.subsurface:
          parentMapped =
              ref.read(subsurfaceStatesProvider(state.parent)).mapped;
        case SurfaceRole.none:
      }
    }

    final mapped = parentMapped &&
        ref.read(surfaceStatesProvider(surfaceId)).textureId.value != -1;

    state = state.copyWith(
      mapped: mapped,
    );
  }

  void set_parent(int parent) {
    state = state.copyWith(
      parent: parent,
    );
    _checkIfMapped();

    if (!ref.read(surfaceIdsProvider).contains(parent)) {
      parentRoleSub?.close();
      parentMappedSub?.close();
      return;
    }

    parentRoleSub?.close();
    parentRoleSub = ref.listen(
      surfaceStatesProvider(parent).select((value) => value.role),
      (_, __) => _checkIfMapped(),
    );

    parentMappedSub?.close();
    // print("$surfaceId, parent: $parent");
    final role = ref.read(surfaceStatesProvider(parent)).role;
    switch (role) {
      case SurfaceRole.xdgSurface:
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
    }
  }

  void commit({required Offset position}) {
    state = state.copyWith(
      position: position,
    );
  }

  void dispose() {
    ref.invalidate(subsurfaceWidgetProvider(surfaceId));
    ref.invalidate(subsurfaceStatesProvider(surfaceId));
  }
}
