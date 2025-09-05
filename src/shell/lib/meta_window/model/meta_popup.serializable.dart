import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/shared/util/json_converter/offset.dart';
import 'package:shell/shared/util/json_converter/rect.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'meta_popup.serializable.freezed.dart';
part 'meta_popup.serializable.g.dart';

typedef MetaPopupId = String;

@freezed
abstract class MetaPopup with _$MetaPopup {
  const factory MetaPopup({
    required MetaPopupId id,
    required MetaWindowId parent,
    required SurfaceId surfaceId,
    required double scaleRatio,
    @OffsetConverter() required Offset position,
    @RectConverter() Rect? geometry,
  }) = _MetaPopup;
  factory MetaPopup.fromJson(Map<String, dynamic> json) =>
      _$MetaPopupFromJson(json);
}
