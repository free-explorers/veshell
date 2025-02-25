import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/persistence/persistable_model.mixin.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/model/window_properties.serializable.dart';

part 'persistent_window.serializable.freezed.dart';
part 'persistent_window.serializable.g.dart';

enum DisplayMode {
  maximized,
  fullscreen,
  game,
  floating,
}

@freezed
class PersistentWindow extends Window
    with _$PersistentWindow
    implements PersistableModel {
  const factory PersistentWindow({
    @PersistentWindowIdConverter() required PersistentWindowId windowId,
    required WindowProperties properties,
    SurfaceId? surfaceId,
    @Default(false) bool isWaitingForSurface,
    @Default(DisplayMode.maximized) DisplayMode displayMode,
    String? customExec,
    List<String>? executionLogs,
  }) = _PersistentWindow;

  factory PersistentWindow.fromJson(Map<String, dynamic> json) =>
      _$PersistentWindowFromJson(json);
}
