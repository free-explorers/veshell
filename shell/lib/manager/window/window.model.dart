import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';

part 'window.model.freezed.dart';

/// Window
@freezed
abstract class Window with _$Window {
  /// Persistent
  const factory Window.persistent({
    required String appId,
    required String title,
    int? surfaceId,
    @Default(false) bool isWaitingForSurface,
  }) = PersistentWindow;

  /// Ephemeral
  const factory Window.ephemeral({
    required String appId,
    required String title,
    required SurfaceId surfaceId,
  }) = EphemeralWindow;

  /// Dialog
  const factory Window.dialog({
    required String appId,
    required String title,
    required SurfaceId surfaceId,
    required int parentSurfaceId,
  }) = DialogWindow;

  /// Popup
  const factory Window.popup({
    required SurfaceId surfaceId,
    required int parentSurfaceId,
  }) = PopupWindow;
}
