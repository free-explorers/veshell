import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'meta_window_dragging_state.g.dart';

/// Who is moving the window.
///
/// A shell title bar drag moves the Flutter box locally; a client-initiated
/// move (`xdg_toplevel.move`, X11 `_NET_WM_MOVERESIZE`) moves the native
/// window itself and arrives back as position patches. Applying pointer deltas
/// in both cases doubled the movement.
enum MetaWindowDragSource { shell, client }

@riverpod
class MetaWindowDraggingState extends _$MetaWindowDraggingState {
  @override
  MetaWindowDragSource? build(MetaWindowId metaWindowId) {
    final subscription = ref.watch(platformManagerProvider).listen((next) {
      if (next case final InteractiveMoveEvent event) {
        if (event.message.metaWindowId == metaWindowId) {
          state = MetaWindowDragSource.client;
        }
      }
    });
    ref.onDispose(subscription.cancel);
    return null;
  }

  /// A drag started by the shell's own title bar.
  void startDragging() {
    state = MetaWindowDragSource.shell;
  }

  void stopDragging() {
    state = null;
  }
}
