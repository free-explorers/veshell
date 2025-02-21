import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/window/model/window_move.dart';

part 'window_move.g.dart';

@Riverpod(keepAlive: true)
class WindowMove extends _$WindowMove {
  @override
  WindowMoveState build(SurfaceId surfaceId) {
    return const WindowMoveState(
      moving: false,
      startPosition: Offset.zero,
      movedPosition: Offset.zero,
      delta: Offset.zero,
    );
  }

  void startPotentialMove() {
    state = state.copyWith(
      moving: false,
      delta: Offset.zero,
    );
  }

  void startMove(Offset position) {
    if (state.moving) {
      return;
    }

    state = state.copyWith(
      moving: true,
      startPosition: position,
    );
    if (state.delta != Offset.zero) {
      state = state.copyWith(
        movedPosition: state.startPosition + state.delta,
      );
    }
  }

  void move(Offset delta) {
    state = state.copyWith(
      delta: state.delta + delta,
    );
    if (state.moving) {
      state = state.copyWith(
        movedPosition: state.startPosition + state.delta,
      );
    }
  }

  void endMove() {
    if (!state.moving) {
      return;
    }
    state = state.copyWith(
      moving: false,
      delta: Offset.zero,
    );
  }

  void cancelMove() {
    if (!state.moving) {
      return;
    }
    state = state.copyWith(
      moving: false,
      delta: Offset.zero,
      movedPosition: state.startPosition,
    );
  }
}
