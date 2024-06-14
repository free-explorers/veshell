import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/window/model/window_properties.serializable.dart';

part 'window_properties.g.dart';

@Riverpod(keepAlive: true)
class WindowPropertiesState extends _$WindowPropertiesState {
  @override
  WindowProperties build(SurfaceId surfaceId) {
    return const WindowProperties(
      appId: '',
      title: null,
    );
  }

  void setAppId(String appId) {
    state = state.copyWith(appId: appId);
  }

  void setTitle(String? title) {
    state = state.copyWith(title: title);
  }

  void setProperties(WindowProperties properties) {
    state = properties;
  }
}
