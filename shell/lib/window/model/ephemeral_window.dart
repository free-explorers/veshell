import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/model/window_id.dart';

part 'ephemeral_window.freezed.dart';

@freezed
class EphemeralWindow with _$EphemeralWindow implements Window {
  const factory EphemeralWindow({
    required EphemeralWindowId windowId,
    required String appId,
    required String title,
    required SurfaceId surfaceId,
  }) = _EphemeralWindow;
}
