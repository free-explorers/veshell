import 'package:collection/collection.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/monitor/provider/monitor_by_view_id.dart';
import 'package:shell/monitor/provider/platform_focused_view.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/monitor_for_screen.dart';
import 'package:shell/screen/provider/screen_for_view.dart';
import 'package:shell/screen/provider/screen_manager.dart';

part 'focused_screen.g.dart';

/// Provide the screen that holds the keyboard, or `null` while no screen
/// exists.
///
/// The compositor is the source of truth for which monitor holds the keyboard
/// ([platformFocusedViewIdProvider]): it moves on a click, never on pointer
/// motion alone. This provider mirrors it onto a screen. Within that monitor, a
/// click on a specific screen picks it, and `setFocusedScreen` records that
/// choice. Where things that surface on their own appear follows the pointer
/// instead (`placementScreenProvider`).
///
/// Startup is deterministic: while the platform-focused monitor is not yet
/// known, the first connected monitor (the compositor's first output) is used;
/// once known, the monitor's primary screen wins until a click refines it.
@Riverpod(keepAlive: true)
class FocusedScreen extends _$FocusedScreen {
  /// The screen the user explicitly focused by clicking it, if any.
  ///
  /// This is tracked separately from [state] because [build] assigns a startup
  /// default; the current state alone cannot distinguish a manual choice from
  /// that default once the notifier keeps its state across rebuilds.
  ScreenId? _manualScreen;

  /// The keyboard's view when [_manualScreen] was chosen, while the
  /// compositor has not reported another one since; `null` once it has.
  ///
  /// A choice on another monitor (a hotkey sent to the screen under the
  /// pointer) is kept until the compositor reports a different view: the
  /// compositor is still moving the keyboard to that monitor, and dropping the
  /// choice before it reports back would hand the keyboard straight back.
  ({int? viewId})? _awaitedViewChange;

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

    final awaited = _awaitedViewChange;
    final awaitingViewChange =
        awaited != null && awaited.viewId == focusedViewId;
    if (!awaitingViewChange) {
      _awaitedViewChange = null;
    }

    final manual = _manualScreen;
    if (manual != null && screenIds.contains(manual)) {
      // Keep a specific screen chosen within the focused monitor (for example
      // by a click), or one chosen since the compositor last reported the
      // focused monitor; a later change of focused monitor overrides it below.
      if (focusedMonitor == null ||
          awaitingViewChange ||
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

    // No platform focus yet: default to the first connected monitor, which is
    // the compositor's first output (both iterate outputs in mapping order).
    // `screenIds.first` is ordered by persisted configuration, not by output,
    // and can point at another monitor.
    final firstMonitorViewId = ref
        .watch(connectedMonitorListProvider)
        .firstOrNull
        ?.viewId;
    if (firstMonitorViewId != null) {
      final firstMonitorScreen = ref.watch(
        screenForViewProvider(firstMonitorViewId),
      );
      if (firstMonitorScreen != null &&
          screenIds.contains(firstMonitorScreen)) {
        return firstMonitorScreen;
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
    _awaitedViewChange = (viewId: ref.read(platformFocusedViewIdProvider));
    state = screenId;
  }
}

/// The screen that may take Flutter focus for the compositor's platform focus,
/// or `null` until the monitor layout is known.
///
/// This is [focusedScreenProvider] gated on the connected monitor list being
/// available: before the layout arrives, [focusedScreenProvider] can only fall
/// back to a persisted screen that may sit on another monitor, and letting it
/// focus would make the engine report that view back as focused and pin the
/// wrong monitor at startup. Once the layout is known, [focusedScreenProvider]
/// picks the first connected monitor (the compositor's first output) and
/// follows clicks from there.
@riverpod
ScreenId? platformFocusedScreen(Ref ref) {
  if (ref.watch(platformFocusedViewIdProvider) == null &&
      ref.watch(connectedMonitorListProvider).isEmpty) {
    return null;
  }
  return ref.watch(focusedScreenProvider);
}
