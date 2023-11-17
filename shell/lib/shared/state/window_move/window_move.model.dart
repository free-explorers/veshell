import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'window_move.model.freezed.dart';

@freezed
class WindowMoveState with _$WindowMoveState {
  const factory WindowMoveState({
    required bool moving,
    required Offset startPosition,
    required Offset movedPosition,
    required Offset delta,
  }) = _WindowMoveState;
}
