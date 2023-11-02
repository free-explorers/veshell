import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/ui/common/state/surface_state.dart';
import 'package:zenith/ui/common/state/xdg_toplevel_state.dart';

part '../../../generated/ui/desktop/state/window_state_provider.freezed.dart';

part '../../../generated/ui/desktop/state/window_state_provider.g.dart';

@Riverpod(keepAlive: true)
class WindowState extends _$WindowState {
  @override
  WindowProviderState build(int viewId) {
    // ref.listen(surfaceStatesProvider(viewId), (previous, next) {
    //   if (state.tilingRequested == null) {
    //     return;
    //   }
    //   if (previous == null || previous.surfaceSize == next.surfaceSize) {
    //     return;
    //   }
    // });

    return WindowProviderState(
      tiling: Tiling.none,
      repaintBoundaryKey: GlobalKey(),
      snapshot: null,
    );
  }

  // void requestMaximize(bool maximize) {
  //   state = state.copyWith(
  //     tilingRequested: maximize ? Tiling.maximized : Tiling.none,
  //   );
  // }

  void setSnapshot(ui.Image? image) {
    state.snapshot?.dispose();
    state = state.copyWith(
      snapshot: image,
    );
  }
}

@freezed
class WindowProviderState with _$WindowProviderState {
  const factory WindowProviderState({
    required Tiling tiling,
    required GlobalKey repaintBoundaryKey,
    required ui.Image? snapshot,
  }) = _WindowProviderState;
}
