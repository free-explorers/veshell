import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/window/model/window_id.dart';

part 'dialog_list_for_window.g.dart';

@Riverpod(keepAlive: true)
class DialogListForWindow extends _$DialogListForWindow {
  @override
  IMapOfSets<WindowId, DialogWindowId> build() {
    return IMapOfSets();
  }

  void add(WindowId parentWindowId, DialogWindowId windowId) {
    state = state.add(parentWindowId, windowId);
  }

  void remove(WindowId parentWindowId, DialogWindowId windowId) {
    state = state.remove(parentWindowId, windowId);
  }
}
