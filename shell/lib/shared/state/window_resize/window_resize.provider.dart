import 'dart:math';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/manager/platform_api/platform_api.provider.dart';
import 'package:shell/shared/state/window_resize/window_resize.model.dart';
import 'package:shell/shared/wayland/xdg_toplevel/xdg_toplevel.model.dart';

part 'window_resize.provider.g.dart';

@Riverpod(keepAlive: true)
class WindowResize extends _$WindowResize {
  @override
  ResizerState build(int surfaceId) {
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
      final delta = _computeResizeOffset(state.delta);
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
      final delta = _computeResizeOffset(state.delta);
      state = state.copyWith(
        wantedSize: state.startSize + delta,
      );

      final int width = max(1, state.wantedSize.width.toInt());
      final int height = max(1, state.wantedSize.height.toInt());

      ref.read(platformApiProvider.notifier).resizeWindow(
            surfaceId,
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

    final int width = max(1, state.wantedSize.width.toInt());
    final int height = max(1, state.wantedSize.height.toInt());

    ref.read(platformApiProvider.notifier).resizeWindow(
          surfaceId,
          width,
          height,
        );
  }

  Offset computeWindowOffset(Size oldSize, Size newSize) {
    final offset = (newSize - oldSize) as Offset;

    final dx = offset.dx;
    final dy = offset.dy;

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
    final dx = delta.dx;
    final dy = delta.dy;

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
