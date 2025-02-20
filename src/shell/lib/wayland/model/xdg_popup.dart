import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'xdg_popup.freezed.dart';

@freezed
class XdgPopup with _$XdgPopup {
  /// Factory for XdgPopup
  const factory XdgPopup({
    required bool committed,
    required SurfaceId parent,
    required Offset position,
  }) = _XdgPopup;
}
