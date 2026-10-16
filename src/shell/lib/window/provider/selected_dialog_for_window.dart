import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
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

/// The meta window a tile should activate: the dialog its single focus node
/// hands the keyboard to, or `null` when no client should be activated (no
/// dialog, or the chooser is selected).
///
/// A modal or fixed-size dialog floats over the tile and sits above everything
/// (see `isFloatingDialog`), so it keeps the keyboard even when a tabbed-area
/// dialog is the one selected; the newest such dialog wins, being on top of the
/// others. Otherwise the selected tab's dialog is activated, defaulting to the
/// newest dialog, which is what the old floating stack always raised.
@riverpod
MetaWindowId? selectedDialogMetaWindowForWindow(Ref ref, WindowId parentId) {
  final dialogIds = ref.watch(dialogSetForWindowProvider(parentId));
  if (dialogIds.isEmpty) {
    return null;
  }

  final floating = _newestFloatingMetaWindowId(ref, dialogIds);
  if (floating != null) {
    return floating;
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

/// The meta window of the newest floating dialog in [dialogIds], or `null` when
/// none of them floats.
MetaWindowId? _newestFloatingMetaWindowId(
  Ref ref,
  Iterable<DialogWindowId> dialogIds,
) {
  for (final dialogWindowId in dialogIds.toList().reversed) {
    try {
      final metaWindowId = ref
          .watch(dialogWindowStateProvider(dialogWindowId))
          .metaWindowId;
      if (isFloatingDialog(ref.watch(metaWindowStateProvider(metaWindowId)))) {
        return metaWindowId;
      }
    } on Object {
      continue;
    }
  }
  return null;
}
