import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/shared/persistence/persistable_model.mixin.dart';
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
    MetaWindowId? metaWindowId,
    @Default(false) bool isWaitingForSurface,
    @Default(DisplayMode.maximized) DisplayMode displayMode,
    String? customExec,
    int? pid,
  }) = _PersistentWindow;

  factory PersistentWindow.fromJson(Map<String, dynamic> json) =>
      _$PersistentWindowFromJson(json);
}
