import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
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

  @override
  void onCurrentlyDisplayedMetaWindowChanged(MetaWindowId? metaWindowId) {
    if (metaWindowId != null) {
      state = state.copyWith(metaWindowId: metaWindowId);
      ref.read(metaWindowStateProvider(state.metaWindowId).notifier).patch(
            MetaWindowPatchMessage.updateDisplayMode(
              id: state.metaWindowId,
              value: MetaWindowDisplayMode.floating,
            ),
          );
    }
  }

  @override
  void onMetaWindowDisplayedPropertiesChanged(MetaWindow metaWindow) {
    state =
        state.copyWith(properties: WindowProperties.fromMetaWindow(metaWindow));
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
