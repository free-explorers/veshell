import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/matching_engine.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/window/provider/window_provider.mixin.dart';

part 'dialog_window_state.g.dart';

/// The display mode a dialog inherits from its owner tile.
///
/// Compatibility contract: every non-floating presentation keeps the
/// historical `maximized` assignment (the dialog area, fullscreen and game
/// modes). Only the floating escape hatch puts its dialogs in floating mode.
MetaWindowDisplayMode dialogMetaWindowDisplayMode(DisplayMode? parentMode) {
  return parentMode == DisplayMode.floating
      ? MetaWindowDisplayMode.floating
      : MetaWindowDisplayMode.maximized;
}

/// Workspace provider
@riverpod
class DialogWindowState extends _$DialogWindowState
    with WindowProviderMixin<DialogWindow> {
  @override
  DialogWindow build(DialogWindowId windowId) {
    throw Exception('DialogWindowState $windowId not yet initialized');
  }

  void update(DialogWindow window) {
    state = window;
  }

  /// Detaches this dialog's native window into a tile, then removes this
  /// dialog.
  ///
  /// The meta window itself stays alive: the target tile takes over its
  /// ownership through the window map, identity coming from the native window
  /// (resolved to a desktop entry when one exists). An existing empty
  /// placeholder of the same application is preferred over a new tile (see
  /// [MatchingEngine.extractMetaWindowToTile]); the tile this dialog hangs off
  /// is excluded so the window cannot simply re-absorb there. The extraction
  /// button in the dialog titlebar is the only entry point.
  ///
  /// Ordering matters: the meta window is detached *before* the tile is chosen
  /// so no rebroadcast ever routes it back here, and the dialog is destroyed
  /// *after* — leaving ownership cleanly re-pointed.
  Future<void> extractToTile() async {
    final metaWindowId = state.metaWindowId;

    matchingLog.info(
      'Extracting dialog $windowId meta window $metaWindowId to a tile',
    );

    // Detach the meta window from this dialog without notifying so the
    // pending reassignment is not routed back here.
    removeMetaWindow(metaWindowId, shouldNotify: false);

    await ref
        .read(matchingEngineProvider.notifier)
        .extractMetaWindowToTile(
          metaWindowId,
          excludedWindowIds: [state.parentWindowId],
        );

    // This leaves the mapping pointing at the chosen persistent window.
    removeWindow();
  }

  /// Moves this dialog under another owner tile.
  ///
  /// A client-declared parent can arrive after the dialog mapped — Electron
  /// exports the parent toplevel asynchronously, so the About dialog is
  /// briefly matched by process sibling. The authoritative parent must win
  /// over that guess, so the dialog follows it instead of staying on the tile
  /// the matcher picked. Its meta window and selection are unchanged; only the
  /// owning tile changes.
  void reparent(WindowId newParent) {
    final oldParent = state.parentWindowId;
    if (oldParent == newParent) {
      return;
    }
    matchingLog.info(
      'Reparenting dialog $windowId from $oldParent to $newParent',
    );
    state = state.copyWith(parentWindowId: newParent);
    ref.read(dialogSetForWindowProvider(oldParent).notifier).remove(windowId);
    ref.read(dialogSetForWindowProvider(newParent).notifier).add(windowId);
    // Re-apply the new owner's presentation (floating vs tiled).
    onCurrentlyDisplayedMetaWindowChanged(state.metaWindowId);
  }

  @override
  void onCurrentlyDisplayedMetaWindowChanged(MetaWindowId? metaWindowId) {
    if (metaWindowId == null) {
      return;
    }
    state = state.copyWith(metaWindowId: metaWindowId);

    // Compatibility: every tiled presentation (including the dialog area,
    // fullscreen and game) keeps the historical `maximized` assignment. Only a
    // floating tile puts its dialogs in floating mode, which is what lets the
    // compositor accept their client-requested positions.
    final parentId = state.parentWindowId;
    DisplayMode? parentMode;
    if (parentId is PersistentWindowId) {
      try {
        parentMode = ref
            .read(persistentWindowStateProvider(parentId))
            .displayMode;
      } on Object {
        // The parent may still be initializing; default to the tiled
        // presentation, which is the compatibility path.
      }
    }
    final notifier = ref.read(
      metaWindowStateProvider(state.metaWindowId).notifier,
    );
    unawaited(
      notifier.patch(
        MetaWindowPatchMessage.updateDisplayMode(
          id: state.metaWindowId,
          value: dialogMetaWindowDisplayMode(parentMode),
        ),
      ),
    );
  }

  @override
  void onMetaWindowDisplayedPropertiesChanged(MetaWindow metaWindow) {
    state = state.copyWith(
      properties: WindowProperties.fromMetaWindow(metaWindow),
    );
  }

  @override
  void onMetaWindowRemoved(MetaWindowId metaWindowId) {
    super.onMetaWindowRemoved(metaWindowId);
    removeWindow();
  }

  @override
  void removeWindow() {
    ref.read(windowManagerProvider.notifier).removeWindow(state.windowId);
    ref
        .read(dialogSetForWindowProvider(state.parentWindowId).notifier)
        .remove(windowId);

    dispose();
  }
}

/// Access to [DialogWindowState] for keepAlive providers.
///
/// riverpod_lint flags keepAlive providers that use auto-dispose ones, but it
/// cannot see a `ref.keepAlive()` link taken by hand. The state pins itself with one from `initialize` until `dispose`
/// ([WindowProviderMixin]), so reading it from a keepAlive provider is safe.
/// Only add accessors here for that reason: route anything else through
/// `ref` so the lint keeps checking it.
extension DialogWindowStateAccess on Ref {
  DialogWindow readDialogWindow(DialogWindowId id) =>
      read(dialogWindowStateProvider(id));

  DialogWindowState dialogWindowNotifier(DialogWindowId id) =>
      read(dialogWindowStateProvider(id).notifier);
}
