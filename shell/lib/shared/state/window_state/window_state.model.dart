import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/wayland/xdg_toplevel/xdg_toplevel.model.dart';

part 'window_state.model.freezed.dart';

@freezed
class WindowProviderState with _$WindowProviderState {
  const factory WindowProviderState({
    required Tiling tiling,
    required GlobalKey repaintBoundaryKey,
    required ui.Image? snapshot,
  }) = _WindowProviderState;
}
