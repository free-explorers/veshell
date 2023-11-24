import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'xdg_toplevel.model.freezed.dart';

@freezed
class XdgToplevelState with _$XdgToplevelState {
  const factory XdgToplevelState({
    required bool visible,
    required Key virtualKeyboardKey,
    required FocusNode focusNode,
    required Object interactiveMoveRequested,
    required ResizeEdgeObject interactiveResizeRequested,
    required ToplevelDecoration decoration,
    required String title,
    required String appId,
    required Tiling? tilingRequested,
  }) = _XdgToplevelState;
}

enum ResizeEdge {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left;

  static ResizeEdge fromInt(int n) {
    switch (n) {
      case 1:
        return top;
      case 2:
        return bottom;
      case 4:
        return left;
      case 5:
        return topLeft;
      case 6:
        return bottomLeft;
      case 8:
        return right;
      case 9:
        return topRight;
      case 10:
        return bottomRight;
      default:
        return bottomRight;
    }
  }
}

class ResizeEdgeObject {
  ResizeEdgeObject(this.edge);
  final ResizeEdge edge;
}

enum ToplevelDecoration {
  none,
  clientSide,
  serverSide;
}

enum Tiling {
  none,
  maximized,
}
