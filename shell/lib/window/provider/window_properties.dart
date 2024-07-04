import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/window_manager/matching_engine.dart';

part 'window_properties.g.dart';

@Riverpod(keepAlive: true)
class WindowPropertiesState extends _$WindowPropertiesState {
  @override
  WindowProperties build(SurfaceId surfaceId) {
    ref.listenSelf(
      (previous, next) {
        if (previous != next) {
          ref.read(matchingEngineProvider.notifier).checkMatching();
        }
      },
    );
    return const WindowProperties(
      appId: '',
    );
  }

  void setAppId(String appId) {
    state = state.copyWith(appId: appId);
  }

  void setTitle(String? title) {
    state = state.copyWith(title: title);
  }

  void setPid(int pid) {
    state = state.copyWith(pid: pid);
  }

  void setProperties({
    String? appId,
    int? pid,
    String? title,
    String? windowClass,
    String? startupId,
  }) {
    state = state.copyWith(
      appId: appId ?? state.appId,
      pid: pid ?? state.pid,
      title: title,
      windowClass: windowClass,
      startupId: startupId,
    );
  }
}
