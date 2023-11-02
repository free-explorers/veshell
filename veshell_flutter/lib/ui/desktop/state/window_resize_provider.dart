import 'dart:math';

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/platform_api.dart';
import 'package:zenith/ui/common/state/xdg_toplevel_state.dart';

part '../../../generated/ui/desktop/state/window_resize_provider.freezed.dart';

part '../../../generated/ui/desktop/state/window_resize_provider.g.dart';

@Riverpod(keepAlive: true)
class WindowResize extends _$WindowResize {
  @override
  ResizerState build(int viewId) {
    return const ResizerState(
      resizing: false,
      resizeEdge: null,
      startSize: Size.zero,
      wantedSize: Size.zero,
      delta: Offset.zero,
    );
  }

  void startPotentialResize() {
    state = state.copyWith(
      resizing: false,
      delta: Offset.zero,
    );
  }

  void startResize(ResizeEdge edge, Size size) {
    if (state.resizing) {
      return;
    }
    state = state.copyWith(
      resizing: true,
      startSize: size,
      resizeEdge: edge,
    );
    if (state.delta != Offset.zero) {
      Offset delta = _computeResizeOffset(state.delta);
      state = state.copyWith(
        wantedSize: state.startSize + delta,
      );
    }
  }

  void resize(Offset delta) {
    state = state.copyWith(
      delta: state.delta + delta,
    );

    if (state.resizing) {
      Offset delta = _computeResizeOffset(state.delta);
      state = state.copyWith(
        wantedSize: state.startSize + delta,
      );

      int width = max(1, state.wantedSize.width.toInt());
      int height = max(1, state.wantedSize.height.toInt());

      ref.read(platformApiProvider.notifier).resizeWindow(
        viewId,
        width,
        height,
      );
    }
  }

  void endResize() {
    if (!state.resizing) {
      return;
    }
    state = state.copyWith(
      resizing: false,
      resizeEdge: null,
      delta: Offset.zero,
    );
  }

  void cancelResize() {
    if (!state.resizing) {
      return;
    }
    state = state.copyWith(
      resizing: false,
      resizeEdge: null,
      delta: Offset.zero,
      wantedSize: state.startSize,
    );

    int width = max(1, state.wantedSize.width.toInt());
    int height = max(1, state.wantedSize.height.toInt());

    ref.read(platformApiProvider.notifier).resizeWindow(
      viewId,
      width,
      height,
    );
  }

  Offset computeWindowOffset(Size oldSize, Size newSize) {
    Offset offset = (newSize - oldSize) as Offset;

    double dx = offset.dx;
    double dy = offset.dy;

    switch (state.resizeEdge) {
      case ResizeEdge.topLeft:
        return Offset(-dx, -dy);
      case ResizeEdge.top:
      case ResizeEdge.topRight:
        return Offset(0, -dy);
      case ResizeEdge.left:
      case ResizeEdge.bottomLeft:
        return Offset(-dx, 0);
      case ResizeEdge.right:
      case ResizeEdge.bottomRight:
      case ResizeEdge.bottom:
      case null:
        return Offset.zero;
    }
  }

  Offset _computeResizeOffset(Offset delta) {
    double dx = delta.dx;
    double dy = delta.dy;

    switch (state.resizeEdge) {
      case ResizeEdge.topLeft:
        return Offset(-dx, -dy);
      case ResizeEdge.top:
        return Offset(0, -dy);
      case ResizeEdge.topRight:
        return Offset(dx, -dy);
      case ResizeEdge.right:
        return Offset(dx, 0);
      case ResizeEdge.bottomRight:
        return Offset(dx, dy);
      case ResizeEdge.bottom:
        return Offset(0, dy);
      case ResizeEdge.bottomLeft:
        return Offset(-dx, dy);
      case ResizeEdge.left:
        return Offset(-dx, 0);
      case null:
        return Offset(dx, dy);
    }
  }
}

@freezed
class ResizerState with _$ResizerState {
  const factory ResizerState({
    required bool resizing,
    required ResizeEdge? resizeEdge,
    required Size startSize,
    required Size wantedSize,
    required Offset delta,
  }) = _ResizerState;
}
