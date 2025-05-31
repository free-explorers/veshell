import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'meta_window_dragging_state.g.dart';

@riverpod
class MetaWindowDraggingState extends _$MetaWindowDraggingState {
  @override
  bool build(MetaWindowId metaWindowId) {
    ref.watch(platformManagerProvider).listen((next) {
      if (next case final InteractiveMoveEvent event) {
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
