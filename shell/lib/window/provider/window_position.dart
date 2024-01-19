import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'window_position.g.dart';

@Riverpod(keepAlive: true)
class WindowPosition extends _$WindowPosition {
  @override
  Offset build(SurfaceId surfaceId) => Offset.zero;

  @override
  set state(Offset value) {
    super.state = _round(value);
  }

  void update(Offset Function(Offset) callback) {
    super.state = _round(callback(state));
  }

  Offset _round(Offset value) =>
      Offset(value.dx.roundToDouble(), value.dy.roundToDouble());
}
