import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/provider/app_launch.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';
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

  /// Whether the application launched for a tile is still running.
  bool live = true;

  @override
  void build() {}

  @override
  void cancelPendingLaunch(WindowId windowId) => cancelled.add(windowId);

  @override
  bool hasLiveLaunch(WindowId windowId) => live;
}

/// Swallows the display-mode patches the tile applies to its window.
class _FakePlatformManager extends PlatformManager {
  @override
  Stream<PlatformEvent> build() => const Stream.empty();

  @override
  Future<void> request(PlatformRequest request) async {}
}

class _FakeMetaWindowState extends MetaWindowState {
  _FakeMetaWindowState({required this.window, this.closeRequested = false});

  final MetaWindow window;

  @override
  final bool closeRequested;

  @override
  MetaWindow build(String id) => window;
}

MetaWindow _metaWindow(String id) => MetaWindow(
  id: id,
  pid: 1,
  mapped: true,
  surfaceId: 0,
  needDecoration: true,
  gameModeActivated: false,
  scaleRatio: 1,
);

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

  ({
    ProviderContainer container,
    _FakeWindowManager windowManager,
    _FakeAppLaunch appLaunch,
  })
  createContainerWithWindow({
    required bool closeRequested,
    required bool launchAlive,
  }) {
    const windowId = EphemeralWindowId('e1');
    const metaWindowId = 'meta-1';
    final windowManager = _FakeWindowManager();
    final appLaunch = _FakeAppLaunch()..live = launchAlive;
    final container = ProviderContainer(
      overrides: [
        windowManagerProvider.overrideWith(() => windowManager),
        appLaunchProvider.overrideWith(() => appLaunch),
        platformManagerProvider.overrideWith(_FakePlatformManager.new),
        metaWindowStateProvider(metaWindowId).overrideWith(
          () => _FakeMetaWindowState(
            window: _metaWindow(metaWindowId),
            closeRequested: closeRequested,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(ephemeralWindowStateProvider(windowId).notifier)
      ..initialize(
        const EphemeralWindow(
          windowId: windowId,
          properties: WindowProperties(appId: 'org.example.App'),
          screenId: 'screen-1',
          metaWindowId: metaWindowId,
        ),
      )
      ..onMetaWindowRemoved(metaWindowId);

    return (
      container: container,
      windowManager: windowManager,
      appLaunch: appLaunch,
    );
  }

  test('an application-replaced window keeps the ephemeral tile alive', () {
    final (:windowManager, :appLaunch, container: _) =
        createContainerWithWindow(closeRequested: false, launchAlive: true);

    expect(
      windowManager.removed,
      isNot(contains(const EphemeralWindowId('e1'))),
    );
    expect(appLaunch.cancelled, isEmpty);
  });

  test('a shell-requested close removes the ephemeral tile', () {
    final (:windowManager, container: _, appLaunch: _) =
        createContainerWithWindow(closeRequested: true, launchAlive: true);

    expect(windowManager.removed, contains(const EphemeralWindowId('e1')));
  });

  test('a window close after the application exited removes the tile', () {
    final (:windowManager, container: _, appLaunch: _) =
        createContainerWithWindow(closeRequested: false, launchAlive: false);

    expect(windowManager.removed, contains(const EphemeralWindowId('e1')));
  });
}
