import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';
import 'package:shell/manager/window/window.manager.dart';

part 'window.model.freezed.dart';

/// Window
@freezed
abstract class Window with _$Window {
  /// Persistent
  const factory Window.persistent({
    required WindowId windowId,
    required String appId,
    required String title,
    SurfaceId? surfaceId,
    @Default(false) bool isWaitingForSurface,
  }) = PersistentWindow;

  /// Ephemeral
  const factory Window.ephemeral({
    required WindowId windowId,
    required String appId,
    required String title,
    required SurfaceId surfaceId,
  }) = EphemeralWindow;

  /// Dialog
  const factory Window.dialog({
    required WindowId windowId,
    required String appId,
    required String title,
    required SurfaceId surfaceId,
    required int parentSurfaceId,
  }) = DialogWindow;
}
