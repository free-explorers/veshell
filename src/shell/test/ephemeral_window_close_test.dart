import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/provider/app_launch.dart';
import 'package:shell/window/model/ephemeral_window.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_manager_state.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';

/// Records the tiles the shell removes, without the persistent-storage
/// machinery the real manager needs.
class _FakeWindowManager extends WindowManager {
  final removed = <WindowId>[];

  @override
  WindowManagerState build() => WindowManagerState(windows: <WindowId>{}.lock);

  @override
  void removeWindow(WindowId windowId) => removed.add(windowId);
}

/// Records pending-launch cancellations instead of driving `systemctl`.
class _FakeAppLaunch extends AppLaunch {
  final cancelled = <WindowId>[];

  @override
  void build() {}

  @override
  void cancelPendingLaunch(WindowId windowId) => cancelled.add(windowId);
}

void main() {
  test('closing an ephemeral window that never got a surface removes it', () {
    const windowId = EphemeralWindowId('e1');
    const screenId = 'screen-1';
    final windowManager = _FakeWindowManager();
    final appLaunch = _FakeAppLaunch();
    final container = ProviderContainer(
      overrides: [
        windowManagerProvider.overrideWith(() => windowManager),
        appLaunchProvider.overrideWith(() => appLaunch),
      ],
    );
    addTearDown(container.dispose);

    // A launch that never produced a window leaves `metaWindowId` null: the
    // mixin's close has nothing to close, so the tile must remove itself and
    // cancel the launch it started.
    container.read(ephemeralWindowStateProvider(windowId).notifier)
      ..initialize(
        const EphemeralWindow(
          windowId: windowId,
          properties: WindowProperties(appId: 'org.example.App'),
          screenId: screenId,
        ),
      )
      ..closeWindow();

    expect(windowManager.removed, contains(windowId));
    expect(appLaunch.cancelled, contains(windowId));
  });
}
