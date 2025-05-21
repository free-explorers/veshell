import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/window/model/window_id.dart';

part 'dialog_set_for_window.g.dart';

@riverpod
class DialogSetForWindow extends _$DialogSetForWindow {
  KeepAliveLink? _keepAliveLink;
  @override
  ISet<DialogWindowId> build(WindowId parentId) {
    return ISet();
  }

  void add(DialogWindowId dialogId) {
    _keepAliveLink ??= ref.keepAlive();
    state = state.add(dialogId);
  }

  void remove(DialogWindowId dialogId) {
    state = state.remove(dialogId);
    if (state.isEmpty) {
      _keepAliveLink?.close();
      _keepAliveLink = null;
    }
  }
}
