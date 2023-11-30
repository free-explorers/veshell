import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/state/window_move/window_move.model.dart';

part 'window_move.provider.g.dart';

@Riverpod(keepAlive: true)
class WindowMove extends _$WindowMove {
  @override
  WindowMoveState build(int surfaceId) {
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
