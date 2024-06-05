import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/window/model/window_properties.dart';

part 'window_properties.g.dart';

@Riverpod(keepAlive: true)
class WindowProperties extends _$WindowProperties {
  @override
  WindowPropertiesState build(SurfaceId surfaceId) {
    return const WindowPropertiesState(
      appId: null,
      title: null,
    );
  }

  void setAppId(String? appId) {
    state = state.copyWith(appId: appId);
  }

  void setTitle(String? title) {
    state = state.copyWith(title: title);
  }
}
