import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/window/model/dialog_area_entry.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/dialog_window_state.dart';

/// The meta windows whose popups may be visible on a tile.
///
/// Non-floating modes mount only the selected dialog tab; client-declared
/// dialogs are rendered by `WindowDialogs`, and game mode hides all dialogs.
/// Passing every dialog to `TilePopupHost` would paint popups of unmounted
/// windows over the visible tile content.
List<MetaWindowId> visiblePopupMetaWindowIds({
  required WidgetRef ref,
  required MetaWindowId? mainMetaWindowId,
  required Iterable<DialogWindowId> dialogWindowIds,
  required bool dialogsEnabled,
  required bool allDialogsVisible,
  required DialogAreaEntry? selectedEntry,
  required bool chooserVisible,
}) {
  final visible = <MetaWindowId>{};
  if (mainMetaWindowId != null) {
    visible.add(mainMetaWindowId);
  }
  if (!dialogsEnabled) {
    return visible.toList(growable: false);
  }

  final areaDialogs = <(DialogWindowId, MetaWindowId)>[];
  final floatingMetaWindows = <MetaWindowId>[];
  for (final dialogWindowId in dialogWindowIds) {
    final metaWindow = _readDialogMetaWindow(ref, dialogWindowId);
    if (metaWindow == null) {
      continue;
    }
    if (allDialogsVisible) {
      visible.add(metaWindow.id);
    } else if (isFloatingDialog(metaWindow)) {
      floatingMetaWindows.add(metaWindow.id);
    } else {
      areaDialogs.add((dialogWindowId, metaWindow.id));
    }
  }
  if (allDialogsVisible) {
    return visible.toList(growable: false);
  }

  visible.addAll(floatingMetaWindows);

  // Mirror `WindowDialogArea`'s selection: a stored area tab wins, otherwise
  // the last area entry is shown. A selected chooser means no area dialog is
  // mounted.
  MetaWindowId? selectedAreaMetaWindowId;
  if (selectedEntry is DialogWindowEntry) {
    for (final (dialogWindowId, metaWindowId) in areaDialogs) {
      if (dialogWindowId.uuid == selectedEntry.id) {
        selectedAreaMetaWindowId = metaWindowId;
        break;
      }
    }
  }
  if (selectedAreaMetaWindowId == null &&
      !chooserVisible &&
      areaDialogs.isNotEmpty) {
    selectedAreaMetaWindowId = areaDialogs.last.$2;
  }
  if (selectedAreaMetaWindowId != null) {
    visible.add(selectedAreaMetaWindowId);
  }
  return visible.toList(growable: false);
}

MetaWindow? _readDialogMetaWindow(
  WidgetRef ref,
  DialogWindowId dialogWindowId,
) {
  try {
    final metaWindowId = ref
        .watch(dialogWindowStateProvider(dialogWindowId))
        .metaWindowId;
    return ref.watch(metaWindowStateProvider(metaWindowId));
  } on Object {
    return null;
  }
}
