import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'subsurface.model.freezed.dart';

@freezed
class SubsurfaceState with _$SubsurfaceState {
  const factory SubsurfaceState({
    required bool mapped,
    required int parent,
    required Offset position, // relative to the parent
    required Key widgetKey,
  }) = _SubsurfaceState;
}
