import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/misc.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/window/model/window_id.serializable.dart';

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

/// Access to [DialogSetForWindow] for keepAlive providers.
///
/// riverpod_lint flags keepAlive providers that use auto-dispose ones, but it
/// cannot see a `ref.keepAlive()` link taken by hand. The set pins itself with one while it holds dialogs, so reading it
/// from a keepAlive provider is safe.
/// Only add accessors here for that reason: route anything else through
/// `ref` so the lint keeps checking it.
extension DialogSetForWindowAccess on Ref {
  ISet<DialogWindowId> readDialogSet(WindowId parentId) =>
      read(dialogSetForWindowProvider(parentId));

  DialogSetForWindow dialogSetNotifier(WindowId parentId) =>
      read(dialogSetForWindowProvider(parentId).notifier);
}
