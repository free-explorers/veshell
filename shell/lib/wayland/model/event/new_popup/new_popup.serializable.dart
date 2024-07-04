import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/util/json_converter/offset.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'new_popup.serializable.freezed.dart';

part 'new_popup.serializable.g.dart';

/// Model for NewPopupMessage
@freezed
sealed class NewPopupMessage with _$NewPopupMessage implements WaylandMessage {
  /// Factory
  factory NewPopupMessage({
    required SurfaceId surfaceId,
    required SurfaceId parent,
    @OffsetConverter() required Offset position,
  }) = _NewPopupMessage;

  factory NewPopupMessage.fromJson(Map<String, dynamic> json) =>
      _$NewPopupMessageFromJson(json);
}
