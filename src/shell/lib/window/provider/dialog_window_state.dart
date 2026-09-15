import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/window/provider/window_provider.mixin.dart';

part 'dialog_window_state.g.dart';

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

  /// Detaches this dialog's native window into a new persistent window placed
  /// on the focused workspace, then removes this dialog.
  ///
  /// The meta window itself stays alive: the new persistent window takes over
  /// its ownership through the window map, identity coming from the native
  /// window (resolved to a desktop entry when one exists). The extraction
  /// button in the dialog titlebar is the only entry point.
  ///
  /// Ordering matters: the meta window is detached *before* the persistent
  /// window is created so no rebroadcast ever routes it back here, and the
  /// dialog is destroyed *after* — leaving ownership cleanly re-pointed.
  Future<void> extractToTile() async {
    final metaWindowId = state.metaWindowId;

    matchingLog.info(
      'Extracting dialog $windowId meta window $metaWindowId '
      'to a new persistent window',
    );

    // Detach the meta window from this dialog without notifying so the
    // pending reassignment is not routed back here.
    removeMetaWindow(metaWindowId, shouldNotify: false);

    await ref
        .read(windowManagerProvider.notifier)
        .createPersistentWindowForMetaWindow(metaWindowId: metaWindowId);

    // Destroying this dialog leaves the mapping to the new persistent window.
    removeWindow();
  }

  @override
  void onCurrentlyDisplayedMetaWindowChanged(MetaWindowId? metaWindowId) {
    if (metaWindowId != null) {
      state = state.copyWith(metaWindowId: metaWindowId);
      ref
          .read(metaWindowStateProvider(state.metaWindowId).notifier)
          .patch(
            MetaWindowPatchMessage.updateDisplayMode(
              id: state.metaWindowId,
              value: MetaWindowDisplayMode.floating,
            ),
          );
    }
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
