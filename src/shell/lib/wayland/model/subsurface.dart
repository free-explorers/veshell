import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'subsurface.freezed.dart';

@freezed
abstract class Subsurface with _$Subsurface {
  const factory Subsurface({
    required bool committed,
    required bool mapped,
    required SurfaceId parent,
    required Offset position, // relative to the parent
  }) = _Subsurface;
}
