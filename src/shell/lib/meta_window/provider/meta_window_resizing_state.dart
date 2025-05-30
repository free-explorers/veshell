import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/platform/model/event/interactive_resize/interactive_resize.serializable.dart';
import 'package:shell/platform/model/event/wayland_event.serializable.dart';
import 'package:shell/platform/provider/wayland.manager.dart';

part 'meta_window_resizing_state.g.dart';

@riverpod
class MetaWindowResizingState extends _$MetaWindowResizingState {
  @override
  ResizeEdge? build(MetaWindowId metaWindowId) {
    ref.watch(waylandManagerProvider).listen((next) {
      if (next case final InteractiveResizeEvent event) {
        {
          if (event.message.metaWindowId == metaWindowId) {
            state = event.message.edge;
          }
        }
      }
    });
    return null;
  }

  void startResizing(ResizeEdge edge) {
    state = edge;
  }

  void stopResizing() {
    state = null;
  }
}
