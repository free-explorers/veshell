import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'subsurface.freezed.dart';

@freezed
class Subsurface with _$Subsurface {
  const factory Subsurface({
    required bool mapped,
    required int parent,
    required Offset position, // relative to the parent
    required Key widgetKey,
  }) = _SubsurfaceState;
}
