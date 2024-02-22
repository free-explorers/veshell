import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/model/window_id.dart';

part 'dialog_window.freezed.dart';

@freezed
class DialogWindow with _$DialogWindow implements Window {
  const factory DialogWindow({
    required DialogWindowId windowId,
    required String appId,
    required String title,
    required SurfaceId surfaceId,
    required int parentSurfaceId,
  }) = _EphemeralWindow;
}
