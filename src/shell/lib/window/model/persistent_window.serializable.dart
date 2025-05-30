import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/model/window_id.serializable.dart';
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
abstract class PersistentWindow extends Window with _$PersistentWindow {
  const factory PersistentWindow({
    required PersistentWindowId windowId,
    required WindowProperties properties,
    MetaWindowId? metaWindowId,
    @Default(false) bool isWaitingForSurface,
    @Default(DisplayMode.maximized) DisplayMode displayMode,
    String? customExec,
    int? pid,
  }) = _PersistentWindow;

  const PersistentWindow._();

  factory PersistentWindow.fromJson(Map<String, dynamic> json) =>
      _$PersistentWindowFromJson(json);
}
