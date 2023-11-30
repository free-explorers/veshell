import 'package:freezed_annotation/freezed_annotation.dart';

part 'window.model.freezed.dart';

/// Window
@freezed
abstract class Window with _$Window {
  /// Persistent
  const factory Window.persistent({
    required String appId,
    required String title,
    int? surfaceId,
  }) = PersistentWindow;

  /// Ephemeral
  const factory Window.ephemeral({
    required String appId,
    required String title,
    required int surfaceId,
  }) = EphemeralWindow;

  /// Dialog
  const factory Window.dialog({
    required String appId,
    required String title,
    required int surfaceId,
    required int parentSurfaceId,
  }) = DialogWindow;

  /// Popup
  const factory Window.popup({
    required int surfaceId,
    required int parentSurfaceId,
  }) = PopupWindow;
}
