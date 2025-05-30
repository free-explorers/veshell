import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/window/model/window_id.serializable.dart';

part 'surface_window_map.g.dart';

@Riverpod(keepAlive: true)
class SurfaceWindowMap extends _$SurfaceWindowMap {
  @override
  IMap<SurfaceId, WindowId> build() {
    return IMap();
  }

  void set(SurfaceId surfaceId, WindowId windowId) {
    state = state.add(surfaceId, windowId);
  }

  void unset(SurfaceId surfaceId) {
    state = state.remove(surfaceId);
  }
}
