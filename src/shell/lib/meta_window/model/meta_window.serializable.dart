import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/util/json_converter/rect.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'meta_window.serializable.freezed.dart';
part 'meta_window.serializable.g.dart';

enum MetaWindowDisplayMode {
  maximized,
  fullscreen,
  floating,
}

typedef MetaWindowId = String;

@freezed
abstract class MetaWindow with _$MetaWindow {
  const factory MetaWindow({
    required MetaWindowId id,
    required int pid,
    required bool mapped,
    required SurfaceId surfaceId,
    required bool needDecoration,
    required bool gameModeActivated,
    String? appId,
    String? parent,
    MetaWindowDisplayMode? displayMode,
    String? title,
    String? windowClass,
    String? startupId,
    String? currentOutput,
    @RectConverter() Rect? geometry,
  }) = _MetaWindow;

  factory MetaWindow.fromJson(Map<String, dynamic> json) =>
      _$MetaWindowFromJson(json);
}
