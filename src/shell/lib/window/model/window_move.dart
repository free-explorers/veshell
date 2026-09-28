import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:material_ui/material_ui.dart';

part 'window_move.freezed.dart';

@freezed
abstract class WindowMoveState with _$WindowMoveState {
  const factory WindowMoveState({
    required bool moving,
    required Offset startPosition,
    required Offset movedPosition,
    required Offset delta,
  }) = _WindowMoveState;
}
