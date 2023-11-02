import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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
    required Offset position, // relative to the parent
    required bool mapped,
    required Key widgetKey,
  }) = _SubsurfaceState;
}

@Riverpod(keepAlive: true)
class SubsurfaceStates extends _$SubsurfaceStates {
  @override
  SubsurfaceState build(int viewId) {
    return SubsurfaceState(
      position: Offset.zero,
      mapped: false,
      widgetKey: GlobalKey(),
    );
  }

  void commit({required Offset position}) {
    state = state.copyWith(
      position: position,
    );
  }

  void map(bool value) {
    state = state.copyWith(
      mapped: value,
    );
  }

  void dispose() {
    ref.invalidate(subsurfaceWidgetProvider(viewId));
    ref.invalidate(subsurfaceStatesProvider(viewId));
  }
}
