import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/manager/surface/xdg_toplevel/xdg_toplevel.model.dart';
import 'package:shell/shared/state/window_state/window_state.model.dart';

part 'window_state.provider.g.dart';

@Riverpod(keepAlive: true)
class WindowState extends _$WindowState {
  @override
  WindowProviderState build(int surfaceId) {
    // ref.listen(surfaceStatesProvider(surfaceId), (previous, next) {
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
