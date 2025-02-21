import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/util/json_converter/offset.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'pointer_focus.serializable.freezed.dart';
part 'pointer_focus.serializable.g.dart';

@freezed
abstract class PointerFocus with _$PointerFocus {
  const factory PointerFocus({
    required SurfaceId surfaceId,
    @OffsetConverter() required Offset globalOffset,
  }) = _PointerFocus;

  factory PointerFocus.fromJson(Map<String, dynamic> json) =>
      _$PointerFocusFromJson(json);
}
