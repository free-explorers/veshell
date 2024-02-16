import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'xdg_surface.freezed.dart';

@freezed
class XdgSurface with _$XdgSurface {
  /// Factory for xdgPopup
  const factory XdgSurface({
    required Rect geometry,
  }) = _XdgSurface;
}
