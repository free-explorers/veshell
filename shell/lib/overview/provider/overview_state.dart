import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/model/overview.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';

part 'overview_state.g.dart';

@riverpod
class OverviewState extends _$OverviewState {
  @override
  Overview build(ScreenId screenId) {
    return Overview(
      screenId: screenId,
      windowList: <EphemeralWindowId>[].lock,
      isDisplayed: false,
    );
  }

  /// Toggle visibility of the overview
  void toggle() {
    state = state.copyWith(isDisplayed: !state.isDisplayed);

    /// If the overview is hidden, close all ephemeral applications
    if (!state.isDisplayed) {
      for (final windowId in state.windowList) {
        ref.read(windowManagerProvider.notifier).closeWindow(windowId);
      }
    }
  }

  /// Start an new Ephemeral Application
  void startEphemeralApplication(
    LocalizedDesktopEntry entry,
  ) {
    final windowId = ref
        .read(windowManagerProvider.notifier)
        .createEphemeralWindowForDesktopEntry(entry, state.screenId);

    state = state.copyWith(
      windowList: state.windowList.add(windowId),
    );

    ref.read(ephemeralWindowStateProvider(windowId).notifier).launchSelf();
  }

  void removeWindow(EphemeralWindowId windowId) {
    state = state.copyWith(
      windowList: state.windowList.remove(windowId),
    );
  }
}
