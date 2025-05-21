import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/meta_window/model/meta_popup.serializable.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/shared/util/json_converter/offset.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'meta_popup_created.serializable.freezed.dart';
part 'meta_popup_created.serializable.g.dart';

/// Model for MetaPopupCreatedMessage
@freezed
sealed class MetaPopupCreatedMessage
    with _$MetaPopupCreatedMessage
    implements WaylandMessage {
  /// Factory
  factory MetaPopupCreatedMessage({
    required MetaPopupId id,
    required MetaWindowId parent,
    required SurfaceId surfaceId,
    @OffsetConverter() required Offset position,
  }) = _MetaPopupCreatedMessage;

  factory MetaPopupCreatedMessage.fromJson(Map<String, dynamic> json) =>
      _$MetaPopupCreatedMessageFromJson(json);
}
