import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'dragging_state.g.dart';

@riverpod
class SurfaceDraggingState extends _$SurfaceDraggingState {
  @override
  bool build(SurfaceId surfaceId) {
    return false;
  }

  void startDragging() {
    state = true;
  }

  void stopDragging() {
    state = false;
  }
}
