import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/persistence/persistable_model.mixin.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/model/window_id.dart';

part 'persistent_window.serializable.freezed.dart';
part 'persistent_window.serializable.g.dart';

@freezed
class PersistentWindow extends Window
    with _$PersistentWindow
    implements PersistableModel {
  const factory PersistentWindow({
    @PersistentWindowIdConverter() required PersistentWindowId windowId,
    required String appId,
    required String title,
    SurfaceId? surfaceId,
    @Default(false) bool isWaitingForSurface,
  }) = _PersistentWindow;

  factory PersistentWindow.fromJson(Map<String, dynamic> json) =>
      _$PersistentWindowFromJson(json);
}
