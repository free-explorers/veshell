import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/window/model/dialog_area_entry.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';

part 'selected_dialog_for_window.g.dart';

/// Which entry of the dialog area owned by [parentId] is selected.
///
/// Kept per parent window so the selection survives the panel remounting (a
/// tile can be rebuilt while its dialogs stay), and so two tiles with dialogs
/// open track their own selection. `null` means "follow the default": the
/// newest entry, which is what the old floating stack always raised.
@riverpod
class SelectedDialogForWindow extends _$SelectedDialogForWindow {
  @override
  DialogAreaEntry? build(WindowId parentId) => null;

  /// Selects [entry], or `null` to fall back to the newest entry.
  void select(DialogAreaEntry? entry) {
    state = entry;
  }
}

/// The meta window of the native dialog currently selected in [parentId]'s
/// dialog area, or `null` when none is (no dialog, or the chooser is selected).
///
/// A tile points its single focus node at this through
/// `WindowWidget.activationTarget`: focusing the tile then activates the
/// selected dialog instead of the window behind it. The chooser is a shell
/// surface, so it activates no client.
@riverpod
MetaWindowId? selectedDialogMetaWindowForWindow(Ref ref, WindowId parentId) {
  final dialogIds = ref.watch(dialogSetForWindowProvider(parentId));
  if (dialogIds.isEmpty) {
    return null;
  }
  final stored = ref.watch(selectedDialogForWindowProvider(parentId));
  if (stored is FileChooserEntry) {
    return null;
  }
  var selected = dialogIds.last;
  if (stored is DialogWindowEntry) {
    for (final id in dialogIds) {
      if (id.uuid == stored.id) {
        selected = id;
        break;
      }
    }
  }
  try {
    return ref.watch(dialogWindowStateProvider(selected)).metaWindowId;
  } on Object {
    return null;
  }
}
