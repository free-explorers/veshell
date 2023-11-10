import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/ui/common/state/surface_ids.dart';
import 'package:zenith/ui/common/state/surface_state.dart';
import 'package:zenith/ui/common/state/xdg_surface_state.dart';
import 'package:zenith/ui/common/subsurface.dart';

part '../../../generated/ui/common/state/subsurface_state.freezed.dart';

part '../../../generated/ui/common/state/subsurface_state.g.dart';

@Riverpod(keepAlive: true)
Subsurface subsurfaceWidget(SubsurfaceWidgetRef ref, int viewId) {
  return Subsurface(
    key: ref.watch(subsurfaceStatesProvider(viewId).select((state) => state.widgetKey)),
    viewId: viewId,
  );
}

@freezed
class SubsurfaceState with _$SubsurfaceState {
  const factory SubsurfaceState({
    required bool mapped,
    required int parent,
    required Offset position, // relative to the parent
    required Key widgetKey,
  }) = _SubsurfaceState;
}

@Riverpod(keepAlive: true)
class SubsurfaceStates extends _$SubsurfaceStates {
  ProviderSubscription<SurfaceRole>? parentRoleSub;
  ProviderSubscription<bool>? parentMappedSub;

  @override
  SubsurfaceState build(int viewId) {
    ref.listen(surfaceStatesProvider(viewId).select((state) => state.textureId), (_, __) => _checkIfMapped());
    ref.listen(surfaceIdsProvider, (_, __) => _checkIfMapped());

    return SubsurfaceState(
      mapped: false,
      parent: 0,
      position: Offset.zero,
      widgetKey: GlobalKey(),
    );
  }

  void _checkIfMapped() {
    bool parentMapped = false;
    if (ref.read(surfaceIdsProvider).contains(state.parent)) {
      var role = ref.read(surfaceStatesProvider(state.parent)).role;
      switch (role) {
        case SurfaceRole.xdgSurface:
          parentMapped = ref.read(xdgSurfaceStatesProvider(state.parent)).mapped;
        case SurfaceRole.subsurface:
          parentMapped = ref.read(subsurfaceStatesProvider(state.parent)).mapped;
        case SurfaceRole.none:
      }
    }

    bool mapped = parentMapped && ref.read(surfaceStatesProvider(viewId)).textureId.value != -1;

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
    parentRoleSub =
        ref.listen(surfaceStatesProvider(parent).select((value) => value.role), (_, __) => _checkIfMapped());

    parentMappedSub?.close();
    // print("$viewId, parent: $parent");
    var role = ref.read(surfaceStatesProvider(parent)).role;
    switch (role) {
      case SurfaceRole.xdgSurface:
        parentMappedSub =
            ref.listen(xdgSurfaceStatesProvider(parent).select((state) => state.mapped), (_, __) => _checkIfMapped());
      case SurfaceRole.subsurface:
        parentMappedSub =
            ref.listen(subsurfaceStatesProvider(parent).select((state) => state.mapped), (_, __) => _checkIfMapped());
      case SurfaceRole.none:
    }
  }

  void commit({required Offset position}) {
    state = state.copyWith(
      position: position,
    );
  }

  void dispose() {
    ref.invalidate(subsurfaceWidgetProvider(viewId));
    ref.invalidate(subsurfaceStatesProvider(viewId));
  }
}
