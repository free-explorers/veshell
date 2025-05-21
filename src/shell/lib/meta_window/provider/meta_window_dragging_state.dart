import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/wayland/model/event/wayland_event.serializable.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'meta_window_dragging_state.g.dart';

@riverpod
class MetaWindowDraggingState extends _$MetaWindowDraggingState {
  @override
  bool build(MetaWindowId metaWindowId) {
    ref.listen(waylandManagerProvider, (_, next) {
      switch (next) {
        case AsyncData(value: final InteractiveMoveEvent event):
          {
            if (event.message.metaWindowId == metaWindowId) {
              state = true;
            }
          }
      }
    });
    return false;
  }

  void startDragging() {
    state = true;
  }

  void stopDragging() {
    state = false;
  }
}
