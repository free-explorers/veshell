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
  /// The screen the user explicitly focused via pointer entry, if any.
  ///
  /// This is tracked separately from [state] because [build] assigns a startup
  /// default; the current state alone cannot distinguish a manual choice from
  /// that default once the notifier keeps its state across rebuilds.
  ScreenId? _manualScreen;

  @override
  ScreenId? build() {
    final screenIds = ref.watch(
      screenManagerProvider.select((value) => value.screenIds),
    );
    if (screenIds.isEmpty) {
      _manualScreen = null;
      return null;
    }

    final focusedViewId = ref.watch(platformFocusedViewIdProvider);
    final focusedMonitor = focusedViewId == null
        ? null
        : ref.watch(monitorByViewIdProvider(focusedViewId));

    final manual = _manualScreen;
    if (manual != null && screenIds.contains(manual)) {
      // Keep a specific screen chosen within the focused monitor (for example
      // by pointer entry); a change of focused monitor overrides it below.
      if (focusedMonitor == null ||
          ref.watch(monitorForScreenProvider(manual)) == focusedMonitor) {
        return manual;
      }
      // The manual choice belongs to another monitor now; forget it so a later
      // rebuild does not resurrect a stale selection.
      _manualScreen = null;
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
      _manualScreen = null;
      state = null;
      return;
    }
    if (!ref.read(screenManagerProvider).screenIds.contains(screenId)) {
      return;
    }
    _manualScreen = screenId;
    state = screenId;
  }
}
