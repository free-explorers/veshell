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
    required double scaleRatio,
    String? appId,
    String? parent,
    String? activatedBy,
    MetaWindowDisplayMode? displayMode,
    String? title,
    String? windowClass,
    String? startupId,
    @Default(false) bool isFixedSized,
    @Default(false) bool isModal,
    /// Client- or shell-negotiated fullscreen state, mirrored from the
    /// compositor. A fullscreen window is treated as a top-level application
    /// surface for routing, not as a dialog.
    @Default(false) bool isFullscreen,
    /// Whether a live screen cast is recording this window. Resolved by the
    /// compositor (consumer pid, then app id) and rendered on the tile and its
    /// workspace; the shell never re-derives the mapping.
    @Default(false) bool isRecording,
    String? currentOutput,
    @RectConverter() Rect? geometry,
  }) = _MetaWindow;

  factory MetaWindow.fromJson(Map<String, dynamic> json) =>
      _$MetaWindowFromJson(json);
}
