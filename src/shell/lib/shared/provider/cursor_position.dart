import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cursor_position.g.dart';

@Riverpod(keepAlive: true)
class CursorPosition extends _$CursorPosition {
  @override
  Offset build() {
    return Offset.zero;
  }

  // Make these public.

  @override
  Offset get state => super.state;

  @override
  set state(Offset value) {
    super.state = value;
  }
}
