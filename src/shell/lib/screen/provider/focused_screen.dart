import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/provider/monitor_by_view_id.dart';
import 'package:shell/monitor/provider/platform_focused_view.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/monitor_for_screen.dart';
import 'package:shell/screen/provider/screen_for_view.dart';
import 'package:shell/screen/provider/screen_manager.dart';

part 'focused_screen.g.dart';

/// Provide the current Focused screen, or `null` while no screen exists.
///
/// The compositor is the source of truth for which monitor is focused
/// ([platformFocusedViewIdProvider]); this provider mirrors it onto a screen.
/// Within the focused monitor, pointer entry can still pick a specific screen,
/// and `setFocusedScreen` records that choice.
///
/// Startup is deterministic: while the platform-focused monitor is not yet
/// known, the first screen is used; once known, the monitor's primary screen
/// wins until pointer entry refines it.
@riverpod
class FocusedScreen extends _$FocusedScreen {
  @override
  ScreenId? build() {
    final screenIds = ref.watch(
      screenManagerProvider.select((value) => value.screenIds),
    );
    if (screenIds.isEmpty) {
      return null;
    }

    final focusedViewId = ref.watch(platformFocusedViewIdProvider);
    final focusedMonitor = focusedViewId == null
        ? null
        : ref.watch(monitorByViewIdProvider(focusedViewId));

    final current = stateOrNull;
    if (current != null && screenIds.contains(current)) {
      // Keep a specific screen chosen within the focused monitor (for example
      // by pointer entry); a change of focused monitor overrides it below.
      if (focusedMonitor == null ||
          ref.watch(monitorForScreenProvider(current)) == focusedMonitor) {
        return current;
      }
    }

    if (focusedViewId != null) {
      final platformScreen = ref.watch(screenForViewProvider(focusedViewId));
      if (platformScreen != null && screenIds.contains(platformScreen)) {
        return platformScreen;
      }
    }
    return screenIds.first;
  }

  void setFocusedScreen(ScreenId? screenId) {
    if (screenId == null) {
      state = null;
      return;
    }
    if (!ref.read(screenManagerProvider).screenIds.contains(screenId)) {
      return;
    }
    state = screenId;
  }
}
