import 'dart:async';

import 'package:flutter/material.dart';

enum XdgSurfaceRole {
  none,
  toplevel,
  popup,
}

enum Edges {
  none,
  top,
  bottom,
  left,
  right,
}

extension EdgesExt on Edges {
  int get id {
    switch (this) {
      case Edges.none:
        return 0;
      case Edges.top:
        return 1 << 0;
      case Edges.bottom:
        return 1 << 1;
      case Edges.left:
        return 1 << 2;
      case Edges.right:
        return 1 << 3;
    }
  }

  bool operator &(int bitmap) {
    return bitmap & id != 0;
  }
}

extension ValueNotifierFutureExt<T> on ValueNotifier<T> {
  Future<T> future() {
    final completer = Completer<T>();

    void valueChanged() {
      removeListener(valueChanged);
      completer.complete(value);
    }

    addListener(valueChanged);
    return completer.future;
  }

  Future<void> waitUntil(bool Function(T) until) async {
    if (until(value)) {
      return;
    }
    while (!until(await future())) {}
  }
}

extension InterleaveExt<T> on Iterable<T> {
  Iterable<T> interleave(T element) sync* {
    final it = iterator;
    if (it.moveNext()) {
      yield it.current;
    }
    while (it.moveNext()) {
      yield element;
      yield it.current;
    }
  }
}

extension FloorToDouble on Size {
  Size floorToDouble() => Size(width.floorToDouble(), height.floorToDouble());
}
