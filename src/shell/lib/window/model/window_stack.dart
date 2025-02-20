import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'window_stack.freezed.dart';

@freezed
class WindowStackState with _$WindowStackState {
  const factory WindowStackState({
    required IList<int> stack,
    required ISet<int> animateClosing,
    required Size desktopSize,
  }) = _WindowStackState;
  const WindowStackState._();

  Iterable<int> get windows => stack;
}
